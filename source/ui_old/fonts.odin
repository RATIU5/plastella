package ui_old

import rl "vendor:raylib"

FONT :: enum u16 {
	BODY_REG_14,
	BODY_BLD_14,
	BODY_REG_16,
	BODY_BLD_16,
	BODY_REG_20,
}

@(private)
load_font :: proc(font_id: u16, font_size: u16, path: cstring) {
	assign_at(
		&state.fonts,
		font_id,
		Raylib_Font{font = rl.LoadFontEx(path, cast(i32)font_size * 2, nil, 0), fontId = font_id},
	)
	rl.SetTextureFilter(state.fonts[font_id].font.texture, rl.TextureFilter.TRILINEAR)
}

load_fonts :: proc() {
	load_font(u16(FONT.BODY_REG_14), 14, "resources/Inter-Medium.ttf")
	load_font(u16(FONT.BODY_BLD_14), 14, "resources/Inter-Bold.ttf")
	load_font(u16(FONT.BODY_REG_16), 16, "resources/Inter-Medium.ttf")
	load_font(u16(FONT.BODY_BLD_16), 16, "resources/Inter-Bold.ttf")
	load_font(u16(FONT.BODY_REG_20), 20, "resources/Inter-Medium.ttf")
}
