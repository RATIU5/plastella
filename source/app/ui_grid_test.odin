package app

import "core:testing"

// track_drag moves pixels between two neighbours and must never push either
// past its own limits, nor change their combined size.
@(test)
test_track_drag_respects_both_limits :: proc(t: ^testing.T) {
	track :: proc(size, min: f32) -> Track {
		return {size = size, min = min}
	}

	cases := [?]struct {
		lo, hi: Track,
		delta:  f32,
		want:   [2]f32,
		moved:  bool,
	} {
		// Unclamped move, both directions.
		{track(200, 100), track(200, 100), 50, {250, 150}, true},
		{track(200, 100), track(200, 100), -50, {150, 250}, true},
		// Clamped by whichever neighbour is shrinking.
		{track(200, 100), track(200, 180), 999, {220, 180}, true},
		{track(200, 180), track(200, 100), -999, {180, 220}, true},
		// Already at the boundary, and a zero delta: nothing moves.
		{track(100, 100), track(300, 100), -10, {100, 300}, false},
		{track(200, 100), track(200, 100), 0, {200, 200}, false},
	}

	for c, i in cases {
		tracks := [2]Track{c.lo, c.hi}
		moved := track_drag(tracks[:], 0, c.delta)
		got := [2]f32{tracks[0].size, tracks[1].size}

		testing.expectf(t, moved == c.moved, "case %d: moved %v, want %v", i, moved, c.moved)
		testing.expectf(t, got == c.want, "case %d: sizes %v, want %v", i, got, c.want)
		testing.expectf(
			t,
			got[0] + got[1] == c.lo.size + c.hi.size,
			"case %d: total drifted to %v",
			i,
			got[0] + got[1],
		)
	}
}
