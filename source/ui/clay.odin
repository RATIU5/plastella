package ui

import clay "../../vendor/clay"
import "base:runtime"
import c "core:c/libc"
import "core:fmt"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

FONT :: enum u16 {
	BODY_REG_14,
	BODY_BLD_14,
}

// All persistent UI state. Heap-allocated and stashed in App_Memory so it
// survives hot reloads (which zero out the DLL's package globals). `state` is
// re-pointed at this struct on every reload via `reload`.
UI_State :: struct {
	clay_context: ^clay.Context,
	arena_memory: [^]u8,
	fonts:        [dynamic]Raylib_Font,
	icon_sheet:   rl.Texture2D,
	icons:        [ICON]Icon,
}

state: ^UI_State

// Surface clay errors instead of swallowing them; layout bugs (duplicate ids,
// arena exhaustion) are silent corruption otherwise.
error_handler :: proc "c" (error_data: clay.ErrorData) {
	context = runtime.default_context()
	msg := string(([^]u8)(error_data.errorText.chars)[:error_data.errorText.length])
	fmt.eprintfln("clay error: %v: %s", error_data.errorType, msg)
}

load_font :: proc(font_id: u16, font_size: u16, path: cstring) {
	assign_at(
		&state.fonts,
		font_id,
		Raylib_Font{font = rl.LoadFontEx(path, cast(i32)font_size * 2, nil, 0), fontId = font_id},
	)
	rl.SetTextureFilter(state.fonts[font_id].font.texture, rl.TextureFilter.TRILINEAR)
}

// Returns the persistent state pointer; the caller must stash it in App_Memory
// and hand it back to `reload` after every hot reload.
init_clay :: proc() -> rawptr {
	state = new(UI_State)

	min_mem_size := cast(c.size_t)clay.MinMemorySize()
	memory := make([^]u8, min_mem_size)
	state.arena_memory = memory
	arena := clay.CreateArenaWithCapacityAndMemory(min_mem_size, memory)

	state.clay_context = clay.Initialize(
		arena,
		{cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()},
		{handler = error_handler},
	)
	clay.SetMeasureTextFunction(measure_text, nil)

	load_font(u16(FONT.BODY_REG_14), 14, "resources/Inter-Medium.ttf")
	load_font(u16(FONT.BODY_BLD_14), 14, "resources/Inter-Bold.ttf")

	load_icons()

	return state
}

// Re-establish the freshly-loaded DLL's view of the persistent state after a
// hot reload. clay's current-context global and the measure-text function
// pointer both live in the old DLL, so they must be re-set here.
reload :: proc(ui_ctx: rawptr) {
	state = (^UI_State)(ui_ctx)
	clay.SetCurrentContext(state.clay_context)
	clay.SetMeasureTextFunction(measure_text, nil)
}

shutdown_clay :: proc() {
	for f in state.fonts {
		rl.UnloadFont(f.font)
	}
	rl.UnloadTexture(state.icon_sheet)
	delete(state.fonts)
	if state.arena_memory != nil {
		free(state.arena_memory)
	}
	free(state)
	state = nil
}

// The canvas clay lays out into, in logical points. Must use the same source as
// the projection (Ortho in frame_begin) so layout and rendering share one
// coordinate space; GetMousePosition is logical too, so hit-testing matches.
canvas_dims :: proc() -> clay.Dimensions {
	return {cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()}
}

// Begin a UI frame: clear the backbuffer and open a clay layout. Panels are
// declared between `frame_begin` and `frame_end`, keeping the clay/raylib frame
// plumbing in `ui` so callers only describe *what* to draw, not *how*.
frame_begin :: proc(mouse: [2]f32, down: bool) {
	rl.BeginDrawing()

	// After a display hot-plug, every DPI getter reads correct but raylib keeps
	// drawing at the old scale — its internal viewport/projection is left stale.
	// Rebuild the transform deterministically from the current sizes each frame:
	// map logical screen coords across the full physical framebuffer. This makes
	// us immune to raylib's stale internal state. See raylib issues #1982, #4834.
	rlgl.Viewport(0, 0, rl.GetRenderWidth(), rl.GetRenderHeight())
	rlgl.MatrixMode(rlgl.PROJECTION)
	rlgl.LoadIdentity()
	rlgl.Ortho(0, f64(rl.GetScreenWidth()), f64(rl.GetScreenHeight()), 0, 0, 1)
	rlgl.MatrixMode(rlgl.MODELVIEW)
	rlgl.LoadIdentity()

	rl.ClearBackground(rl.BLACK)
	clay.SetLayoutDimensions(canvas_dims())
	clay.SetPointerState(mouse, down)
	clay.BeginLayout()
}

// Close the clay layout, render the resulting commands, and present the frame.
frame_end :: proc() {
	commands := clay.EndLayout(rl.GetFrameTime())
	clay_render(&commands)
	rl.EndDrawing()
}

// cornerRadius is authored as a raylib roundness fraction (0..1 of the shorter
// side), not absolute pixels — this is how the Rectangle case feeds it to
// DrawRectangleRounded. corner_radius_px converts it the same way so borders
// land concentric with the background. Shared segment count keeps the two arcs
// aligned.
CORNER_SEGMENTS :: 16

corner_radius_px :: proc(frac, w, h: f32) -> f32 {
	return clamp(frac, 0, 1) * min(w, h) * 0.5
}

clay_render :: proc(commands: ^clay.ClayArray(clay.RenderCommand)) {
	for i in 0 ..< commands.length {
		cmd := clay.RenderCommandArray_Get(commands, i)
		bbox := cmd.boundingBox

		switch cmd.commandType {
		case .None:
		// no-op
		case .Rectangle:
			rect := cmd.renderData.rectangle
			rl.DrawRectangleRounded(
				{bbox.x, bbox.y, bbox.width, bbox.height},
				rect.cornerRadius.bottomLeft,
				CORNER_SEGMENTS,
				clay_color_to_rl_color(rect.backgroundColor),
			)
		case .Text:
			t := cmd.renderData.text
			ctext := rl.TextFormat("%.*s", t.stringContents.length, t.stringContents.chars)
			font := state.fonts[t.fontId].font
			rl.DrawTextEx(
				font,
				ctext,
				{bbox.x, bbox.y},
				f32(t.fontSize),
				f32(t.letterSpacing),
				clay_color_to_rl_color(t.textColor),
			)
		case .Border:
			// Draw each side independently so partial borders (e.g. right-only)
			// render, and fill each rounded corner with a ring arc so borders
			// follow the element's cornerRadius. Mirrors clay's reference renderer.
			b := cmd.renderData.border
			color := clay_color_to_rl_color(b.color)
			x, y, w, h := bbox.x, bbox.y, bbox.width, bbox.height

			// Corner radii in pixels, matching how the background rounds.
			r := clay.CornerRadius {
				topLeft     = corner_radius_px(b.cornerRadius.topLeft, w, h),
				topRight    = corner_radius_px(b.cornerRadius.topRight, w, h),
				bottomLeft  = corner_radius_px(b.cornerRadius.bottomLeft, w, h),
				bottomRight = corner_radius_px(b.cornerRadius.bottomRight, w, h),
			}

			// Sides: each straight segment is shortened by the corner radii at its ends.
			if b.width.left > 0 {
				lw := f32(b.width.left)
				rl.DrawRectangleRec({x, y + r.topLeft, lw, h - r.topLeft - r.bottomLeft}, color)
			}
			if b.width.right > 0 {
				rw := f32(b.width.right)
				rl.DrawRectangleRec(
					{x + w - rw, y + r.topRight, rw, h - r.topRight - r.bottomRight},
					color,
				)
			}
			if b.width.top > 0 {
				tw := f32(b.width.top)
				rl.DrawRectangleRec({x + r.topLeft, y, w - r.topLeft - r.topRight, tw}, color)
			}
			if b.width.bottom > 0 {
				bw := f32(b.width.bottom)
				rl.DrawRectangleRec(
					{x + r.bottomLeft, y + h - bw, w - r.bottomLeft - r.bottomRight, bw},
					color,
				)
			}

			// Corners: ring arc from (cornerRadius - side width) out to cornerRadius.
			ring :: proc(center: rl.Vector2, inner, outer, start, end: f32, color: rl.Color) {
				if outer <= 0 {
					return
				}
				rl.DrawRing(center, max(inner, 0), outer, start, end, CORNER_SEGMENTS, color)
			}
			ring(
				{x + r.topLeft, y + r.topLeft},
				r.topLeft - f32(b.width.top),
				r.topLeft,
				180,
				270,
				color,
			)
			ring(
				{x + w - r.topRight, y + r.topRight},
				r.topRight - f32(b.width.top),
				r.topRight,
				270,
				360,
				color,
			)
			ring(
				{x + r.bottomLeft, y + h - r.bottomLeft},
				r.bottomLeft - f32(b.width.bottom),
				r.bottomLeft,
				90,
				180,
				color,
			)
			ring(
				{x + w - r.bottomRight, y + h - r.bottomRight},
				r.bottomRight - f32(b.width.bottom),
				r.bottomRight,
				0,
				90,
				color,
			)
		case .ScissorStart:
			rl.BeginScissorMode(i32(bbox.x), i32(bbox.y), i32(bbox.width), i32(bbox.height))
		case .ScissorEnd:
			rl.EndScissorMode()
		case .Image:
			img := cmd.renderData.image
			icon := (^Icon)(img.imageData)
			dest := rl.Rectangle{bbox.x, bbox.y, bbox.width, bbox.height}
			rl.DrawTexturePro(
				icon.texture,
				icon.src,
				dest,
				{0, 0},
				0,
				// Tint set per-use on the Icon; white sheet glyph × tint recolors it.
				clay_color_to_rl_color(icon.tint),
			)
		case .Custom, .OverlayColorStart, .OverlayColorEnd:
		// not handled yet
		}
	}
}
