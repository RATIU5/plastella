package assets

import platform "../platform"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"

Assets :: struct {
	fonts:    [Font_Type]^ttf.Font,
	textures: [Texture_Type]^sdl.Texture,
}

@(require_results)
assets_load :: proc(a: ^Assets, device: ^platform.Device) -> bool {
	load_fonts(a)
	load_textures(a, device)
	return true
}

assets_unload :: proc(a: ^Assets) {
	unload_textures(a)
	unload_fonts(a)
	a^ = {}
}
