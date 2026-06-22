package render

import textures "textures"
import rl "vendor:raylib"

TEXTURES :: enum u16 {
	UI_ICONS,
}

@(private)
texture_slices: [TEXTURES]textures.Texture_Slice

// Use when needing once instance of a texture
texture_slice :: proc(id: TEXTURES, crop: [4]f32 = {}) -> ^textures.Texture_Slice {
	tex := &state.textures[id]
	rect := rl.Rectangle{crop.x, crop.y, crop.z, crop.w}
	if crop == {} {
		rect = {0, 0, f32(tex.width), f32(tex.height)}
	}
	texture_slices[id] = {
		tex  = tex,
		crop = rect,
	}
	return &texture_slices[id]
}

@(private)
load_textures :: proc() {
	load_texture(.UI_ICONS, textures.UI_ICON_PATH)
	textures.load_ui_icons(&state.textures[.UI_ICONS])
}

@(private)
unload_textures :: proc() {
	for tex in state.textures do rl.UnloadTexture(tex)
}

@(private = "file")
load_texture :: proc(id: TEXTURES, path: cstring) {
	state.textures[id] = rl.LoadTexture(path)
	rl.SetTextureFilter(state.textures[id], .BILINEAR)
	rl.GenTextureMipmaps(&state.textures[id])
}
