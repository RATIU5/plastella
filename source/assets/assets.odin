package assets

import platform "../platform"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"

Font_Id :: enum u8 {
	UI_REG_15,
	UI_REG_14,
	UI_BLD_14,
}

Texture_Id :: enum u8 {
	None,
}

Assets :: struct {
	fonts:    [Font_Id]^ttf.Font,
	textures: [Texture_Id]^sdl.Texture,
}

assets_load :: proc(a: ^Assets, device: ^platform.Device) -> bool {
	// TODO: load assets
	// TODO: assert that Font_Id is less than max for u8 (font ids are u16 in clay)
	return true
}

assets_unload :: proc(a: ^Assets) {
	// TODO: unload assets
}
