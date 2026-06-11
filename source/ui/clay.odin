package ui

import clay "../../vendor/clay"
import c "core:c/libc"
import rl "vendor:raylib"

FONT :: enum u16 {
	BODY_REG_14,
	BODY_BLD_14,
}

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
	// TODO: Free memory once done
	memory := make([^]u8, min_mem_size)
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
