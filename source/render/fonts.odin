package render

import rl "vendor:raylib"

FONT_SUPERSAMPLE :: 2

FONT :: enum u16 {
	UI_REG_15,
	UI_REG_14,
	UI_BLD_14,
}

get_font :: proc(id: FONT) -> rl.Font {
	return state.fonts[id]
}

get_glyph_info :: proc(id: FONT, cp: rune) -> rl.GlyphInfo {
	return rl.GetGlyphInfo(state.fonts[id], cp)
}

get_glyph_index :: proc(id: FONT, cp: rune) -> i32 {
	return rl.GetGlyphIndex(state.fonts[id], cp)
}

@(private)
load_font :: proc(id: FONT, size: u16, path: cstring) {
	state.fonts[id] = rl.LoadFontEx(path, i32(size) * FONT_SUPERSAMPLE, nil, 0)
	rl.SetTextureFilter(state.fonts[id].texture, rl.TextureFilter.TRILINEAR)
}

@(private)
load_fonts :: proc() {
	load_font(.UI_REG_15, 15, "resources/fonts/Inter-Medium.ttf")
	load_font(.UI_REG_14, 14, "resources/fonts/Inter-Medium.ttf")
	load_font(.UI_BLD_14, 14, "resources/fonts/Inter-Bold.ttf")
}

@(private)
unload_fonts :: proc() {
	for font in state.fonts do rl.UnloadFont(font)
}
