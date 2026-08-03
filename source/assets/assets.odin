package assets

import "../platform"
import "core:fmt"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"

Assets :: struct {
	fonts:    [Text]^ttf.Font,
	textures: [Texture_Id]^sdl.Texture,
	ui_icons: [Ui_Icons]Texture_Slice,
	scale:    f32,
}

@(require_results)
assets_load :: proc(a: ^Assets, device: ^platform.Device) -> bool {
	fonts_ok := load_fonts(a, device)
	if !fonts_ok {
		fmt.eprintln("Failed to load font assets")
		return false
	}
	tex_ok := load_textures(a, device)
	if !tex_ok {
		fmt.eprintln("Failed to load texture assets")
		return false
	}
	load_ui_icons(a, a.textures[.Icons])
	return true
}

assets_unload :: proc(a: ^Assets) {
	unload_textures(a)
	unload_fonts(a)
	a^ = {}
}
