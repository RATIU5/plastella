package app

import "../../vendor/clay"
import "../platform"
import "core:fmt"

GRID_TRACKS_MAX :: 8

Axis :: enum u8 {
	X,
	Y,
}

// Authored as fractions of the track space and resolved to px by grid_update,
// so panels keep their proportions at any window size. min_px is the floor a
// fraction alone cannot express: on a small window a percentage resolves to
// fewer pixels than the content needs, and the content is what overflows.
// No max: a track's ceiling is already whatever its neighbours' minimums leave.
Track :: struct {
	frac:     f32,
	min_frac: f32,
	min_px:   f32,
	size:     f32,
	min:      f32,
}

Grid :: struct {
	tracks:    [Axis][GRID_TRACKS_MAX]Track,
	count:     [Axis]int,
	gap:       f32,
	pad:       f32,
	// Fractions are of the space left after the gaps, but clay's percent is of
	// the whole inner box, so percents carry this correction.
	pct_scale: [Axis]f32,
}

// Percent, not pixels, so clay resolves against the window being drawn now.
// A pixel size would come from the box measured last frame, which during a
// live resize is always one window behind and hangs off the edge.
@(require_results)
grid_size :: proc(grid: ^Grid, axis: Axis, i: int) -> clay.SizingAxis {
	n := grid.count[axis]
	assert(i >= 0)
	assert(i < n)

	scale := grid.pct_scale[axis]
	if scale <= 0 do scale = 1
	return clay.SizingPercent(grid.tracks[axis][i].frac * scale)
}

@(require_results)
grid_col :: proc(grid: ^Grid, i: int) -> clay.SizingAxis {
	return grid_size(grid, .X, i)
}

@(require_results)
grid_row :: proc(grid: ^Grid, i: int) -> clay.SizingAxis {
	return grid_size(grid, .Y, i)
}

// Must run before the cells are laid out, or the clamp lands a frame late and
// the overflowing size is what gets rendered. Uses last frame's container box.
grid_update :: proc(ctx: ^Ctx, grid: ^Grid, container_id: string) {
	data := clay.GetElementData(clay.ID(container_id))
	if !data.found do return

	for axis in Axis {
		n := grid.count[axis]
		if n < 2 do continue

		tracks := grid.tracks[axis][:n]
		extent := grid_extent(grid, axis, data.boundingBox)
		inner := grid_cross(grid, axis, data.boundingBox)
		if extent <= 0 || inner <= 0 do continue

		grid.pct_scale[axis] = extent / inner

		total_min := f32(0)
		for &track in tracks {
			track.size = track.frac * extent
			track.min = max(track.min_frac * extent, track.min_px)
			total_min += track.min
		}

		// Below the floors there is no honest layout left, so scale them down
		// together rather than letting the tracks overflow the window.
		if total_min > extent {
			for &track in tracks do track.min *= extent / total_min
			total_min = extent
		}

		slack := extent - total_min

		used := f32(0)
		for &track in tracks[:n - 1] {
			track.size = clamp(track.size, track.min, track.min + slack)
			slack -= track.size - track.min
			used += track.size
		}

		// Last track takes the remainder, so the sizes always sum to extent and
		// the fractions below always sum to 1. Slack accounting leaves it its min.
		tracks[n - 1].size = extent - used
		assert(tracks[n - 1].size >= tracks[n - 1].min - 0.5)

		for i in 0 ..< n - 1 {
			grid_drag(ctx, grid, tracks, container_id, axis, i)
		}

		for &track in tracks do track.frac = track.size / extent
	}
}

// Space the tracks share, so the gaps come out before the fractions apply.
@(private = "file", require_results)
grid_extent :: proc(grid: ^Grid, axis: Axis, box: clay.BoundingBox) -> f32 {
	return grid_cross(grid, axis, box) - grid.gap * f32(grid.count[axis] - 1)
}

@(private = "file", require_results)
grid_cross :: proc(grid: ^Grid, axis: Axis, box: clay.BoundingBox) -> f32 {
	return (box.width if axis == .X else box.height) - grid.pad * 2
}

@(private = "file")
grid_drag :: proc(
	ctx: ^Ctx,
	grid: ^Grid,
	tracks: []Track,
	container_id: string,
	axis: Axis,
	i: int,
) {
	id := grid_seam_id(container_id, axis, i)
	state := &ctx.frame.gfx.interaction

	claimable := state.pressed_id[.Left] == ""
	if claimable && pointer_over(id) && platform.mouse_pressed(ctx.frame.input, .Left) {
		state.pressed_id[.Left] = id
	}
	// interaction_end is never called, so the seam drops its own press.
	if state.pressed_id[.Left] == id && !platform.mouse_down(ctx.frame.input, .Left) {
		state.pressed_id[.Left] = ""
	}
	if state.pressed_id[.Left] != id do return

	// The seam's own measured box, so there is no second opinion about where
	// clay actually put it.
	seam := clay.GetElementData(clay.ID(id))
	if !seam.found do return

	origin := seam.boundingBox.x if axis == .X else seam.boundingBox.y
	want := ctx.frame.input.mouse.pos[int(axis)] - grid.gap * 0.5
	if track_drag(tracks, i, want - origin) {
		app.frames_owed = max(app.frames_owed, 1)
	}
}

// Emit between two cells, in place of the container's childGap, which must be 0.
grid_seam :: proc(ctx: ^Ctx, grid: ^Grid, container_id: string, axis: Axis, i: int) {
	id := grid_seam_id(container_id, axis, i)
	pressed := ctx.frame.gfx.interaction.pressed_id[.Left]

	// A held drag owns the pointer, so no other seam may hover out from under it.
	lit := pressed == id || (pressed == "" && pointer_over(id))

	if lit do ctx.frame.cursor = .Resize_EW if axis == .X else .Resize_NS

	line := f32(1) if lit else 0

	if clay.UI(clay.ID(id))(
	{
		layout = {
			sizing = {
				width = clay.SizingFixed(grid.gap) if axis == .X else clay.SizingGrow(),
				height = clay.SizingGrow() if axis == .X else clay.SizingFixed(grid.gap),
			},
			childAlignment = {x = .Center, y = .Center},
		},
	},
	) {
		if clay.UI(clay.ID(fmt.tprintf("%s:line", id)))(
		{
			layout = {
				sizing = {
					width = clay.SizingFixed(line) if axis == .X else clay.SizingGrow(),
					height = clay.SizingGrow() if axis == .X else clay.SizingFixed(line),
				},
			},
			backgroundColor = COLOR_ACCENT,
		},
		) {}
	}
}

@(private = "file", require_results)
grid_seam_id :: proc(container_id: string, axis: Axis, i: int) -> string {
	return fmt.tprintf("%s:seam:%v:%d", container_id, axis, i)
}

// Bounded by both neighbours' minimums, so a drag can never starve either.
track_drag :: proc(tracks: []Track, i: int, delta: f32) -> bool {
	assert(i >= 0)
	assert(i + 1 < len(tracks))

	lo := tracks[i].min - tracks[i].size
	hi := tracks[i + 1].size - tracks[i + 1].min
	if lo > hi do return false

	d := clamp(delta, lo, hi)
	if d == 0 do return false

	tracks[i].size += d
	tracks[i + 1].size -= d
	return true
}
