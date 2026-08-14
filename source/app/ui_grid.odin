package app

import "../../vendor/clay"
import "../platform"
import "core:fmt"
import sdl "vendor:sdl3"

GRID_TRACKS_MAX :: 8
GRID_HOVER_DELAY_MS :: u64(150)

Axis :: enum u8 {
	X,
	Y,
}

// Axis doubles as an index into mouse.pos and friends.
#assert(int(Axis.X) == 0)
#assert(int(Axis.Y) == 1)

// Seed values for a track's first sighting. After that the dragged size wins,
// so changing frac in code only takes effect on a fresh grid.
// A zero max means unbounded; the two forms combine as min(max_frac, max_px).
Track_Opts :: struct {
	frac:     f32,
	min_frac: f32,
	min_px:   f32,
	max_frac: f32,
	max_px:   f32,
}

// min_px is the floor a fraction alone cannot express: on a small window a
// percentage resolves to fewer pixels than the content needs, and the content
// is what overflows. max_px is the same idea inverted, for a panel that should
// stay short however large the window gets.
Track :: struct {
	name:     string,
	id:       u32,
	frac:     f32,
	min_frac: f32,
	min_px:   f32,
	max_frac: f32,
	max_px:   f32,
	size:     f32,
	min:      f32,
	max:      f32,
}

// Tracks register themselves in layout order on first sighting, so a Grid
// belongs to one container with a stable set of panels. Call grid_reset when
// that set changes, such as a container swapping layouts between tabs.
Grid :: struct {
	tracks:    [Axis][GRID_TRACKS_MAX]Track,
	count:     [Axis]int,
	gap:       f32,
	pad:       f32,
	// Fractions are of the space left after the gaps, but clay's percent is of
	// the whole inner box, so percents carry this correction.
	pct_scale: [Axis]f32,
	container: string,
	// One slot, since only one seam can be under the pointer at a time.
	hover_id:  string,
	hover_ms:  u64,
}

// Layout for the container the tracks live in, which owns the padding and must
// not add a childGap, since the seam elements are the gaps.
@(require_results)
grid_container_layout :: proc(
	grid: ^Grid,
	container_id: string,
	dir: clay.LayoutDirection,
) -> clay.LayoutConfig {
	grid.container = container_id
	pad := u16(grid.pad)
	return {
		sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
		padding = {pad, pad, pad, pad},
		layoutDirection = dir,
	}
}

// Layout for a row or column of cells nested inside the container. Padding here
// would desync the cells from the percentages, which are of the container.
@(require_results)
grid_group_layout :: proc(dir: clay.LayoutDirection, sizing: clay.Sizing) -> clay.LayoutConfig {
	return {sizing = sizing, layoutDirection = dir}
}

@(require_results)
grid_col :: proc(grid: ^Grid, name: string, opts := Track_Opts{}) -> clay.SizingAxis {
	return grid_track(grid, .X, name, opts)
}

@(require_results)
grid_row :: proc(grid: ^Grid, name: string, opts := Track_Opts{}) -> clay.SizingAxis {
	return grid_track(grid, .Y, name, opts)
}

// Percent, not pixels, so clay resolves against the window being drawn now. A
// pixel size would come from the box measured last frame, which during a live
// resize is always one window behind and hangs off the edge.
@(require_results)
grid_track :: proc(grid: ^Grid, axis: Axis, name: string, opts: Track_Opts) -> clay.SizingAxis {
	i := grid_register(grid, axis, name, opts)

	scale := grid.pct_scale[axis]
	if !grid_measured(grid, axis) do scale = 1
	return clay.SizingPercent(grid.tracks[axis][i].frac * scale)
}

// Tracks register during layout, so the first frame runs before grid_update has
// ever measured the container and the percentages carry no gap allowance yet.
@(private = "file", require_results)
grid_measured :: proc(grid: ^Grid, axis: Axis) -> bool {
	return grid.pct_scale[axis] > 0
}

// Emit between two cells, where the container's childGap would have been.
// `after` names the track on the leading side of the seam.
grid_seam :: proc(ctx: ^Ctx, grid: ^Grid, axis: Axis, after: string) {
	i, found := grid_index(grid, axis, after)
	if !found do return

	id := grid_seam_id(grid, axis, i)
	pressed := ctx.frame.gfx.interaction.pressed_id[.Left]

	// A held drag owns the pointer, so no other seam may hover out from under it.
	hovered := pressed == "" && pointer_over(id)
	// Leaving resets the clock, so re-entering waits again instead of firing
	// instantly off a stale timestamp.
	if !hovered && grid.hover_id == id do grid.hover_id = ""

	lit := pressed == id || (hovered && grid_hover_elapsed(ctx, grid, id))

	if lit do ctx.frame.cursor = .Resize_EW if axis == .X else .Resize_NS

	line := f32(1) if lit else 0

	// Until the percentages account for the gaps, the tracks already claim the
	// whole container, so a seam with width here would overflow it by exactly
	// the gap and shove the last panel off the edge for a frame.
	gap := grid.gap if grid_measured(grid, axis) else 0

	if clay.UI(clay.ID(id))(
	{
		layout = {
			sizing = {
				width = clay.SizingFixed(gap) if axis == .X else clay.SizingGrow(),
				height = clay.SizingGrow() if axis == .X else clay.SizingFixed(gap),
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

// A seam only offers itself once the pointer has settled on it, so crossing the
// gap on the way somewhere else does not flash the cursor. Owed frames keep the
// idle loop awake for the wait, since the pointer sitting still raises no events.
@(private = "file")
grid_hover_elapsed :: proc(ctx: ^Ctx, grid: ^Grid, id: string) -> bool {
	now := sdl.GetTicks()
	if grid.hover_id != id {
		grid.hover_id = id
		grid.hover_ms = now
	}

	if now - grid.hover_ms >= GRID_HOVER_DELAY_MS do return true

	app.frames_owed = max(app.frames_owed, 1)
	return false
}

// Must run before the cells are laid out, or the clamp lands a frame late and
// the overflowing size is what gets rendered. Uses last frame's container box,
// so it is a no-op until the container has been drawn once.
grid_update :: proc(ctx: ^Ctx, grid: ^Grid) {
	if grid.container == "" do return

	data := clay.GetElementData(clay.ID(grid.container))
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

			track.max = track.max_frac * extent if track.max_frac > 0 else extent
			if track.max_px > 0 do track.max = min(track.max, track.max_px)
			track.max = max(track.max, track.min)

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
			track.size = clamp(track.size, track.min, min(track.min + slack, track.max))
			slack -= track.size - track.min
			used += track.size
		}

		// Last track takes the remainder, so the sizes always sum to extent and
		// the fractions below always sum to 1. Slack accounting leaves it its min.
		last := &tracks[n - 1]
		last.size = extent - used
		assert(last.size >= last.min - 0.5)

		// Taking the remainder would otherwise let the last track ignore its own
		// max, so hand the excess back to whoever still has headroom.
		excess := last.size - last.max
		if excess > 0 {
			last.size = last.max
			for &track in tracks[:n - 1] {
				if excess <= 0 do break
				give := min(track.max - track.size, excess)
				track.size += give
				excess -= give
			}
		}

		for i in 0 ..< n - 1 {
			grid_drag(ctx, grid, tracks, axis, i)
		}

		for &track in tracks do track.frac = track.size / extent
	}
}

// Forgets every registered track, for a container that swaps its set of panels.
grid_reset :: proc(grid: ^Grid) {
	grid.count = {}
	grid.pct_scale = {}
}

// Registers on first sighting, in call order, which is why call order must match
// visual order: seam `i` sits between tracks `i` and `i+1`.
@(private = "file")
grid_register :: proc(grid: ^Grid, axis: Axis, name: string, opts: Track_Opts) -> int {
	if i, found := grid_index(grid, axis, name); found do return i

	n := grid.count[axis]
	assert(n < GRID_TRACKS_MAX)

	// Seeds only have to be sane; grid_update renormalises them against its
	// neighbours on the next pass.
	grid.tracks[axis][n] = {
		name     = name,
		id       = clay.ID(name).id,
		frac     = opts.frac if opts.frac > 0 else 1,
		min_frac = opts.min_frac,
		min_px   = opts.min_px,
		max_frac = opts.max_frac,
		max_px   = opts.max_px,
	}
	grid.count[axis] = n + 1
	return n
}

@(private = "file", require_results)
grid_index :: proc(grid: ^Grid, axis: Axis, name: string) -> (int, bool) {
	id := clay.ID(name).id
	for track, i in grid.tracks[axis][:grid.count[axis]] {
		if track.id == id do return i, true
	}
	return 0, false
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
grid_drag :: proc(ctx: ^Ctx, grid: ^Grid, tracks: []Track, axis: Axis, i: int) {
	id := grid_seam_id(grid, axis, i)
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

@(private = "file", require_results)
grid_seam_id :: proc(grid: ^Grid, axis: Axis, i: int) -> string {
	return fmt.tprintf("%s:seam:%v:%s", grid.container, axis, grid.tracks[axis][i].name)
}

// Bounded by both neighbours' limits, so a drag can never starve or overfill either.
track_drag :: proc(tracks: []Track, i: int, delta: f32) -> bool {
	assert(i >= 0)
	assert(i + 1 < len(tracks))

	lo := max(tracks[i].min - tracks[i].size, tracks[i + 1].size - tracks[i + 1].max)
	hi := min(tracks[i].max - tracks[i].size, tracks[i + 1].size - tracks[i + 1].min)
	if lo > hi do return false

	d := clamp(delta, lo, hi)
	if d == 0 do return false

	tracks[i].size += d
	tracks[i + 1].size -= d
	return true
}
