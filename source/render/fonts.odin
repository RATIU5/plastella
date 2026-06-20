package render

import be "../render_backend"
import rl "vendor:raylib"

FONT_SUPERSAMPLE :: 2

FONT :: enum u16 {
	UI_REG_14,
	UI_BLD_14,
}

@(private)
load_font :: proc(id: FONT, size: u16, path: cstring) {
	when be.BACKEND == .Raylib {
		state.fonts[id] = rl.LoadFontEx(path, i32(size) * FONT_SUPERSAMPLE, nil, 0)
		rl.SetTextureFilter(state.fonts[id].texture, rl.TextureFilter.TRILINEAR)
	}
}

@(private)
load_fonts :: proc() {
	load_font(.UI_REG_14, 14, "resources/fonts/Inter-Medium.ttf")
	load_font(.UI_BLD_14, 14, "resources/fonts/Inter-Bold.ttf")
}

@(private)
unload_fonts :: proc() {
	when be.BACKEND == .Raylib {
		for font in state.fonts do rl.UnloadFont(font)
	}
}
