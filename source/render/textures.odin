package render

import be "../render_backend"
import textures "textures"
import rl "vendor:raylib"

TEXTURES :: enum u16 {
	UI_ICONS,
}

@(private)
load_textures :: proc() {
	load_texture(.UI_ICONS, textures.UI_ICON_PATH)
	textures.load_ui_icons(&state.textures[.UI_ICONS])
}

@(private)
unload_textures :: proc() {
	when be.BACKEND == .Raylib {
		for tex in state.textures do rl.UnloadTexture(tex)
	}
}

@(private = "file")
load_texture :: proc(id: TEXTURES, path: cstring) {
	when be.BACKEND == .Raylib {
		state.textures[id] = rl.LoadTexture(path)
		rl.SetTextureFilter(state.textures[id], .BILINEAR)
		rl.GenTextureMipmaps(&state.textures[id])
	}
}
