package app

import "core:testing"

// Bounds are optional and independent, and an absent one must never move a value.
@(test)
test_number_clamp_bounds :: proc(t: ^testing.T) {
	cases := [?]struct {
		value: f32,
		lo:    Maybe(f32),
		hi:    Maybe(f32),
		want:  f32,
	} {
		{5, nil, nil, 5},
		{-100, nil, nil, -100},
		{-1, f32(0), nil, 0},
		{-1, nil, f32(0), -1},
		{99, nil, f32(10), 10},
		{99, f32(0), f32(10), 10},
		{5, f32(0), f32(10), 5},
		{0, f32(0), f32(10), 0},
		{10, f32(0), f32(10), 10},
	}

	for c, i in cases {
		got := number_clamp(c.value, c.lo, c.hi)
		testing.expectf(t, got == c.want, "case %d: got %v, want %v", i, got, c.want)
	}
}

double_step :: proc(value: f32, dir: int) -> f32 {
	return value * 2 if dir > 0 else value * 0.5
}

// Deflection sets a rate: nothing in the deadzone, mirrored across the origin,
// linear as it grows, saturating at the far edge, and cut short by a narrow field.
@(test)
test_number_scrub_rate_curve :: proc(t: ^testing.T) {
	MAX :: NUMBER_SCRUB_MAX_PX
	CAP :: f32(30)

	testing.expect(t, number_scrub_rate(0, MAX, CAP) == 0, "moved at the origin")
	testing.expect(
		t,
		number_scrub_rate(NUMBER_SCRUB_DEAD_PX, MAX, CAP) == 0,
		"moved in the deadzone",
	)

	// Clearing the deadzone must move the value, not stall in a flat curve.
	just_out := number_scrub_rate(NUMBER_SCRUB_DEAD_PX + 1, MAX, CAP)
	testing.expectf(t, just_out >= NUMBER_SCRUB_RATE_MIN, "stalled at %v steps/s", just_out)

	prev := f32(0)
	for px := NUMBER_SCRUB_DEAD_PX + 1; px <= MAX; px += 1 {
		rate := number_scrub_rate(px, MAX, CAP)
		testing.expectf(t, rate > prev, "rate did not grow at %v (%v <= %v)", px, rate, prev)
		testing.expectf(t, number_scrub_rate(-px, MAX, CAP) == -rate, "%v is not mirrored", px)
		prev = rate
	}

	testing.expectf(t, prev == CAP, "full deflection is %v, want the cap %v", prev, CAP)
	testing.expect(t, number_scrub_rate(MAX * 10, MAX, CAP) == CAP, "rate kept growing past the max")

	// Linear: the midpoint sits halfway between the floor and the cap.
	floor := min(NUMBER_SCRUB_RATE_MIN, CAP * 0.25)
	mid := number_scrub_rate((MAX + NUMBER_SCRUB_DEAD_PX) * 0.5, MAX, CAP)
	testing.expectf(t, abs(mid - (floor + CAP) * 0.5) < 0.01, "midpoint %v is not linear", mid)

	// A narrow field tops out below the cap however far the pointer travels.
	narrow := number_scrub_rate(MAX * 10, MAX * 0.5, CAP)
	testing.expectf(t, narrow < CAP * 0.6, "narrow field reached %v of cap %v", narrow, CAP)
	testing.expectf(
		t,
		narrow == number_scrub_rate(MAX * 0.5, MAX * 0.5, CAP),
		"narrow field kept growing past its width",
	)
}

// The cap comes from the size of the range, so a short ladder ticks over slowly,
// a long range flies, and neither sags as it approaches a bound.
@(test)
test_number_scrub_rate_max_follows_range :: proc(t: ^testing.T) {
	// 16 -> 64 -> 256: two rungs.
	ladder := Number_Opts {
		step_proc = quad_step,
		lo        = f32(16),
		hi        = f32(256),
	}
	testing.expect(t, number_steps_to_end(16, 1, ladder) == 2, "up span from 16")
	testing.expect(t, number_steps_to_end(64, 1, ladder) == 1, "up span from 64")
	testing.expect(t, number_steps_to_end(16, -1, ladder) == 0, "down span from 16")

	rungs := number_scrub_rate_max(ladder)
	testing.expectf(t, rungs == 2 / NUMBER_SCRUB_SWEEP_S, "ladder paces at %v", rungs)

	long := Number_Opts {
		step = 1,
		lo   = f32(1),
		hi   = f32(99),
	}
	testing.expectf(
		t,
		number_scrub_rate_max(long) > rungs * 20,
		"a long range must scrub far faster than a short ladder",
	)

	// An open end has no range to pace against, so it scrubs at full speed.
	testing.expect(t, number_scrub_rate_max({step = 1}) == NUMBER_SCRUB_RATE_MAX, "unbounded")
	testing.expect(
		t,
		number_scrub_rate_max({step = 1, lo = f32(0)}) == NUMBER_SCRUB_RATE_MAX,
		"half-open",
	)
}

// The default format seeds the text field, so it must parse back and carry no sign.
@(test)
test_number_format_default :: proc(t: ^testing.T) {
	cases := [?]struct {
		value: f32,
		want:  string,
	}{{0, "0"}, {32, "32"}, {-32, "-32"}, {0.5, "0.5"}, {-0.25, "-0.25"}, {4096, "4096"}}

	for c, i in cases {
		buf: [NUMBER_FMT_MAX_BYTES]u8
		got := number_format_default(c.value, buf[:])
		testing.expectf(t, got == c.want, "case %d: got %q, want %q", i, got, c.want)
	}
}

// A commit that will not parse keeps the last good value; one out of range is
// pulled in and flagged.
@(test)
test_number_parse_reverts_bad_commits :: proc(t: ^testing.T) {
	opts := Number_Opts {
		lo = f32(1),
		hi = f32(99),
	}

	cases := [?]struct {
		text:    string,
		want:    f32,
		invalid: bool,
		clamped: bool,
	} {
		{"42", 42, false, false},
		{"  42  ", 42, false, false},
		{"7.5", 8, false, false},
		{"", 5, true, false},
		{"-", 5, true, false},
		{".", 5, true, false},
		{"1.2.3", 5, true, false},
		{"12-", 5, true, false},
		{"0", 1, false, true},
		{"-8", 1, false, true},
		{"1000", 99, false, true},
	}

	for c, i in cases {
		got, invalid, clamped, _ := number_parse(c.text, 5, opts)
		testing.expectf(t, got == c.want, "case %d (%q): got %v, want %v", i, c.text, got, c.want)
		testing.expectf(t, invalid == c.invalid, "case %d (%q): invalid %v", i, c.text, invalid)
		testing.expectf(t, clamped == c.clamped, "case %d (%q): clamped %v", i, c.text, clamped)
	}
}

// A hold steps once on press, waits out the delay, then fires at a fixed rate,
// and the release that ends the run is swallowed instead of stepping again.
@(test)
test_number_repeat_schedule :: proc(t: ^testing.T) {
	n: Number_Drag
	ID :: "inc"

	fire, ended := number_repeat(&n, ID, true, 1000)
	testing.expect(t, !fire && !ended, "press itself must not repeat")

	for now in u64(1001) ..= 1000 + NUMBER_REPEAT_DELAY_MS - 1 {
		fire, ended = number_repeat(&n, ID, true, now)
		testing.expectf(t, !fire, "fired at %d, before the delay elapsed", now)
	}

	fire, ended = number_repeat(&n, ID, true, 1000 + NUMBER_REPEAT_DELAY_MS)
	testing.expect(t, fire, "no fire once the delay elapsed")

	fire, _ = number_repeat(&n, ID, true, 1000 + NUMBER_REPEAT_DELAY_MS + 1)
	testing.expect(t, !fire, "fired faster than the rate")

	rate_at := 1000 + NUMBER_REPEAT_DELAY_MS + NUMBER_REPEAT_RATE_MS
	fire, _ = number_repeat(&n, ID, true, rate_at)
	testing.expect(t, fire, "no fire at the rate boundary")

	// Release: the click that ends a repeat run is not another step.
	fire, ended = number_repeat(&n, ID, false, rate_at + 1)
	testing.expect(t, !fire, "fired after release")
	testing.expect(t, ended, "release after repeats must be swallowed")

	// A short click never repeats, so its release still counts.
	n = {}
	_, _ = number_repeat(&n, ID, true, 5000)
	fire, ended = number_repeat(&n, ID, false, 5010)
	testing.expect(t, !fire, "short click fired a repeat")
	testing.expect(t, !ended, "short click must keep its release")
}

quad_step :: proc(value: f32, dir: int) -> f32 {
	return value * 4 if dir > 0 else value / 4
}

// A committed number must land on a value the steps can produce: the nearest
// rung of a ladder, or the nearest multiple of a scalar step from `lo`.
@(test)
test_number_snap_to_reachable :: proc(t: ^testing.T) {
	ladder := Number_Opts {
		step_proc = quad_step,
		lo        = f32(16),
		hi        = f32(256),
	}

	rungs := [?]struct {
		value, want: f32,
	} {
		{16, 16},
		{64, 64},
		{256, 256},
		{100, 64},
		{17, 16},
		{63, 64},
		{200, 256},
		// Ties round down, to the rung already passed.
		{40, 16},
	}
	for c, i in rungs {
		got := number_snap(c.value, ladder)
		testing.expectf(
			t,
			got == c.want,
			"rung %d: snap(%v) = %v, want %v",
			i,
			c.value,
			got,
			c.want,
		)
	}

	// Scalar steps grid off `lo`, so an odd start stays reachable.
	grid := Number_Opts {
		step = 5,
		lo   = f32(2),
		hi   = f32(97),
	}
	for c, i in ([?][2]f32{{2, 2}, {7, 7}, {8, 7}, {10, 12}, {96, 97}}) {
		got := number_snap(c[0], grid)
		testing.expectf(t, got == c[1], "grid %d: snap(%v) = %v, want %v", i, c[0], got, c[1])
	}

	// A commit reports the snap so the caller can say why it moved.
	value, invalid, clamped, snapped := number_parse("100", 16, ladder)
	testing.expectf(t, value == 64, "commit landed on %v", value)
	testing.expect(t, !invalid && !clamped, "100 is a number and is in range")
	testing.expect(t, snapped, "off-ladder commit was not reported")

	value, _, _, snapped = number_parse("64", 16, ladder)
	testing.expect(t, value == 64 && !snapped, "an on-ladder commit must not report a snap")
}
