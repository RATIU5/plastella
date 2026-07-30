package assets

import platform "../platform"
import "core:fmt"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"

Assets :: struct {
	fonts:    [Text]^ttf.Font,
	textures: [Texture_Id]^sdl.Texture,
	scale:    f32,
}

@(require_results)
assets_load :: proc(a: ^Assets, device: ^platform.Device) -> bool {
	fonts_ok := load_fonts(a, device)
	if !fonts_ok {
		fmt.eprintln("Failed to load font assets")
		return false
	}
	load_textures(a, device)
	return true
}

assets_unload :: proc(a: ^Assets) {
	unload_textures(a)
	unload_fonts(a)
	a^ = {}
}
