package render

import rl "vendor:raylib"

FONT :: enum u16 {
	UI_REG_14,
	UI_BLD_14,
}

@(private)
load_font :: proc(id: FONT, size: u16, path: cstring) {
	state.fonts[id] = rl.LoadFontEx(path, i32(size) * 2, nil, 0)
	rl.SetTextureFilter(state.fonts[id].texture, rl.TextureFilter.TRILINEAR)
}

load_fonts :: proc() {
	load_font(.UI_REG_14, 14, "resources/Inter-Medium.ttf")
	load_font(.UI_BLD_14, 14, "resources/Inter-Bold.ttf")
}

unload_fonts :: proc() {
	for font in state.fonts do rl.UnloadFont(font)
}
