package app

import "core:testing"

// Tracks register on first sighting in call order and are idempotent after, so
// re-rendering a frame must not grow the grid or shuffle seam indices.
@(test)
test_grid_registers_in_call_order :: proc(t: ^testing.T) {
	grid: Grid

	for _ in 0 ..< 3 {
		_ = grid_col(&grid, "overview", {frac = 0.5})
		_ = grid_col(&grid, "settings", {frac = 0.5})
		_ = grid_row(&grid, "top", {frac = 0.6})
		_ = grid_row(&grid, "bottom", {frac = 0.4})
	}

	testing.expectf(t, grid.count[.X] == 2, "cols = %d, want 2", grid.count[.X])
	testing.expectf(t, grid.count[.Y] == 2, "rows = %d, want 2", grid.count[.Y])

	// Axes are independent, and order follows the calls, not the names.
	testing.expect(t, grid.tracks[.X][0].name == "overview")
	testing.expect(t, grid.tracks[.X][1].name == "settings")
	testing.expect(t, grid.tracks[.Y][0].name == "top")
	testing.expect(t, grid.tracks[.Y][1].name == "bottom")

	grid_reset(&grid)
	testing.expectf(t, grid.count[.X] == 0, "reset left %d cols", grid.count[.X])
}

// track_drag moves pixels between two neighbours and must never push either
// past its own limits, nor change their combined size.
@(test)
test_track_drag_respects_both_limits :: proc(t: ^testing.T) {
	track :: proc(size, min: f32, max := f32(10000)) -> Track {
		return {size = size, min = min, max = max}
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
		// Clamped by the growing track's own max.
		{track(200, 100, 220), track(200, 100), 999, {220, 180}, true},
		// Clamped by the shrinking track's max, reached from the other side.
		{track(200, 100), track(200, 100, 220), -999, {180, 220}, true},
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
