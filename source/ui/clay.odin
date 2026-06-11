package ui

import clay "../../vendor/clay"
import c "core:c/libc"
import rl "vendor:raylib"

FONT :: enum u16 {
	BODY_REG_14,
	BODY_BLD_14,
}

clay_arena_memory: [^]u8

error_handler :: proc "c" (error_data: clay.ErrorData) {
	if (error_data.errorType == clay.ErrorType.DuplicateId) {
		// etc
	}
}

load_font :: proc(font_id: u16, font_size: u16, path: cstring) {
	assign_at(
		&raylib_fonts,
		font_id,
		Raylib_Font{font = rl.LoadFontEx(path, cast(i32)font_size * 2, nil, 0), fontId = font_id},
	)
	rl.SetTextureFilter(raylib_fonts[font_id].font.texture, rl.TextureFilter.TRILINEAR)
}

init_clay :: proc() {
	min_mem_size := cast(c.size_t)clay.MinMemorySize()
	memory := make([^]u8, min_mem_size)
	clay_arena_memory = memory
	arena := clay.CreateArenaWithCapacityAndMemory(min_mem_size, memory)

	clay.Initialize(
		arena,
		{cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()},
		{handler = error_handler},
	)
	clay.SetMeasureTextFunction(measure_text, nil)

	load_font(u16(FONT.BODY_REG_14), 14, "resources/Inter-Medium.ttf")
	load_font(u16(FONT.BODY_BLD_14), 14, "resources/Inter-Bold.ttf")
}

shutdown_clay :: proc() {
	for f in raylib_fonts {
		rl.UnloadFont(f.font)
	}
	delete(raylib_fonts)
	if clay_arena_memory != nil {
		free(clay_arena_memory)
		clay_arena_memory = nil
	}
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
				0,
				0,
				clay_color_to_rl_color(rect.backgroundColor),
			)
		case .Text:
			t := cmd.renderData.text
			text_str := string(t.stringContents.chars[:t.stringContents.length])
			ctext := rl.TextFormat("%.*s", t.stringContents.length, t.stringContents.chars)
			font := raylib_fonts[t.fontId].font
			rl.DrawTextEx(
				font,
				ctext,
				{bbox.x, bbox.y},
				f32(t.fontSize),
				f32(t.letterSpacing),
				clay_color_to_rl_color(t.textColor),
			)
			_ = text_str
		case .Border:
			b := cmd.renderData.border
			rl.DrawRectangleLinesEx(
				{bbox.x, bbox.y, bbox.width, bbox.height},
				f32(b.width.left),
				clay_color_to_rl_color(b.color),
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
