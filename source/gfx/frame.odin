package gfx

import "../assets"
import "../platform"

Frame :: struct {
	gfx:    ^Gfx,
	device: ^platform.Device,
	assets: ^assets.Assets,
	input:  ^platform.Input,
	screen: [2]f32,
	dt:     f32,
	cursor: platform.Cursor,
}
