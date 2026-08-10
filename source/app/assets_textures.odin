package app

import "../platform"
import "core:fmt"
import sdl "vendor:sdl3"
import img "vendor:sdl3/image"

Texture_Id :: enum u8 {
	Icons,
	Logo,
}

Texture_Slice :: struct {
	tex:  ^sdl.Texture,
	crop: sdl.Rect,
	tint: [4]f32,
}

@(rodata)
texture_paths := [Texture_Id]cstring {
	.Icons = "resources/textures/ui_icons.png",
	.Logo  = "resources/textures/logo.png",
}

@(require_results)
load_textures :: proc(a: ^Assets, device: ^platform.Device) -> bool {
	for path, type in texture_paths {
		a.textures[type] = img.LoadTexture(device.renderer, path)
		if a.textures[type] == nil {
			fmt.eprintfln("failed to load %s: %s", path, sdl.GetError())
			unload_textures(a)
			return false
		}
		sdl.SetTextureScaleMode(a.textures[type], .NEAREST)
	}
	return true
}

unload_textures :: proc(a: ^Assets) {
	for tex in a.textures do if tex != nil do sdl.DestroyTexture(tex)
	a.textures = {}
	a.ui_icons = {} // slices cache the atlas texture pointer
}

@(require_results)
texture_slice :: proc(a: ^Assets, id: Texture_Id) -> Texture_Slice {
	tex := a.textures[id]
	return {tex = tex, crop = {x = 0, y = 0, w = tex.w, h = tex.h}, tint = {255, 255, 255, 255}}
}
