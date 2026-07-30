package assets

import platform "../platform"
import "core:fmt"
import sdl "vendor:sdl3"
import img "vendor:sdl3/image"

Texture_Id :: enum u8 {
	Icons,
}

Texture_Paths :: [Texture_Id]cstring {
	.Icons = "resources/textures/ui_icons.png",
}

load_textures :: proc(a: ^Assets, device: ^platform.Device) -> bool {
	for path, type in Texture_Paths {
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
}
