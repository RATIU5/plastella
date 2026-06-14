package ui

import clay "../../vendor/clay"
import "base:runtime"
import c "core:c/libc"
import "core:fmt"
import rl "vendor:raylib"

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
	delete(state.fonts)
	if state.arena_memory != nil {
		free(state.arena_memory)
	}
	free(state)
	state = nil
}

// Begin a UI frame: clear the backbuffer and open a clay layout. Panels are
// declared between `frame_begin` and `frame_end`, keeping the clay/raylib frame
// plumbing in `ui` so callers only describe *what* to draw, not *how*.
frame_begin :: proc(mouse: [2]f32, down: bool) {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	clay.SetLayoutDimensions({cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()})
	clay.SetPointerState(mouse, down)
	clay.BeginLayout()
}

// Close the clay layout, render the resulting commands, and present the frame.
frame_end :: proc() {
	commands := clay.EndLayout(rl.GetFrameTime())
	clay_render(&commands)
	rl.EndDrawing()
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
				4,
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
			b := cmd.renderData.border
			color := clay_color_to_rl_color(b.color)
			w := f32(b.width.left)
			rl.DrawRectangleRoundedLinesEx(
				{
					x = bbox.x + w,
					y = bbox.y + w,
					width = bbox.width - 2 * w,
					height = bbox.height - 2 * w,
				},
				b.cornerRadius.bottomLeft,
				4,
				w,
				color,
			)
		case .ScissorStart:
			rl.BeginScissorMode(i32(bbox.x), i32(bbox.y), i32(bbox.width), i32(bbox.height))
		case .ScissorEnd:
			rl.EndScissorMode()
		case .Image, .Custom, .OverlayColorStart, .OverlayColorEnd:
		// not handled yet
		}
	}
}
