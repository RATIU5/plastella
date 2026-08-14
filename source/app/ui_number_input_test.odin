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

// The scrub rate eases in from the press point, mirrors across it, saturates at
// the far edge, and the outer half is boosted well past the plain cubic.
@(test)
test_number_scrub_rate_curve :: proc(t: ^testing.T) {
	MAX :: NUMBER_SCRUB_MAX_PX

	testing.expect(t, number_scrub_rate(0, NUMBER_SCRUB_RATE_MAX) == 0, "moved at the origin")
	testing.expect(
		t,
		number_scrub_rate(NUMBER_SCRUB_DEAD_PX, NUMBER_SCRUB_RATE_MAX) == 0,
		"moved inside the deadzone",
	)
	testing.expect(
		t,
		number_scrub_rate(-NUMBER_SCRUB_DEAD_PX, NUMBER_SCRUB_RATE_MAX) == 0,
		"moved inside the deadzone",
	)

	// Clearing the deadzone must move the value, not stall in a flat curve.
	just_out := number_scrub_rate(NUMBER_SCRUB_DEAD_PX + 1, NUMBER_SCRUB_RATE_MAX)
	testing.expectf(t, just_out >= NUMBER_SCRUB_RATE_MIN, "stalled at %v steps/s", just_out)

	// Direction only flips the sign.
	for px in ([?]f32{10, 50, 99, MAX, MAX * 10}) {
		testing.expectf(
			t,
			number_scrub_rate(-px, NUMBER_SCRUB_RATE_MAX) ==
			-number_scrub_rate(px, NUMBER_SCRUB_RATE_MAX),
			"%v is not mirrored",
			px,
		)
	}

	// Strictly faster the further out, until it saturates.
	prev := f32(0)
	for px := NUMBER_SCRUB_DEAD_PX + 1; px <= MAX; px += 1 {
		rate := number_scrub_rate(px, NUMBER_SCRUB_RATE_MAX)
		testing.expectf(t, rate > prev, "rate did not grow at %v (%v <= %v)", px, rate, prev)
		prev = rate
	}
	testing.expect(
		t,
		number_scrub_rate(MAX * 10, NUMBER_SCRUB_RATE_MAX) == prev,
		"rate kept growing past the max",
	)

	// Past halfway the boost ramps in, so the far edge dwarfs the midpoint.
	half := number_scrub_rate(MAX * 0.5, NUMBER_SCRUB_RATE_MAX)
	full := number_scrub_rate(MAX, NUMBER_SCRUB_RATE_MAX)
	testing.expectf(t, full > half * 8, "boost too weak: %v vs %v", full, half)
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
		{"7.5", 7.5, false, false},
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
		got, invalid, clamped := number_parse(c.text, 5, opts)
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

// A step_proc with only a few rungs must scrub slowly enough to land on the
// middle ones, while a long range keeps the full rate.
@(test)
test_number_scrub_rate_max_follows_range :: proc(t: ^testing.T) {
	// 16 -> 64 -> 256: two transitions.
	ladder := Number_Opts {
		step_proc = quad_step,
		lo        = f32(16),
		hi        = f32(256),
	}
	testing.expectf(
		t,
		number_range_steps(ladder) == 2,
		"ladder span = %v, want 2",
		number_range_steps(ladder),
	)

	// Full deflection sweeps the range in about the sweep time, not instantly.
	// The floor rate eats a little of the span, so allow a quarter of slack.
	edge := number_scrub_rate(NUMBER_SCRUB_MAX_PX, number_scrub_rate_max(ladder))
	want := 2 / NUMBER_SCRUB_SWEEP_S
	testing.expectf(t, edge <= want, "ladder edge rate %v exceeds %v", edge, want)
	testing.expectf(t, edge >= want * 0.75, "ladder edge rate %v is far under %v", edge, want)

	long := Number_Opts {
		step = 1,
		lo   = f32(1),
		hi   = f32(99),
	}
	testing.expect(t, number_range_steps(long) == 98, "long span is wrong")
	testing.expect(
		t,
		number_scrub_rate(NUMBER_SCRUB_MAX_PX, number_scrub_rate_max(long)) > edge * 20,
		"a long range must scrub far faster than a short ladder",
	)

	// An open-ended range has no span to pace against.
	testing.expect(t, number_range_steps({step = 1, lo = f32(0)}) == 0, "half-open span")
	testing.expect(
		t,
		number_scrub_rate_max({step = 1}) == NUMBER_SCRUB_RATE_MAX,
		"unbounded throttled",
	)
}

quad_step :: proc(value: f32, dir: int) -> f32 {
	return value * 4 if dir > 0 else value / 4
}
