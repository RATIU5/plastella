package gfx

import assets "../assets"
import platform "../platform"

Frame :: struct {
	gfx:    ^Gfx,
	device: ^platform.Device,
	assets: ^assets.Assets,
	input:  ^platform.Input,
	screen: [2]f32,
	dt:     f32,
}
