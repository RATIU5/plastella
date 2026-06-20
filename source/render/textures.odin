package render

import textures "textures"
import rl "vendor:raylib"

TEXS :: enum u16 {
	UI_ICONS,
}

@(private)
load_texture :: proc(id: TEXS, path: cstring) {
	state.textures[id] = rl.LoadTexture(path)
	rl.SetTextureFilter(state.textures[id], .BILINEAR)
	rl.GenTextureMipmaps(&state.textures[id])
}

@(private)
unload_texture :: proc(id: TEXS) {
	rl.UnloadTexture(state.textures[id])
}

load_textures :: proc() {
	load_texture(.UI_ICONS, textures.UI_ICON_PATH)
}

unload_textures :: proc() {
	textures.unload_ui_icons()

	for tex in state.textures do rl.UnloadTexture(tex)
}
