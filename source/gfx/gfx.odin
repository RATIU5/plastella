package gfx

import clay "../../vendor/clay"
import assets "../assets"
import "core:fmt"
import sdl "vendor:sdl3"

Gfx :: struct {
	clay_ctx: ^clay.Context,
	clay_mem: [^]u8,
}

#assert(len(assets.Text) <= int(max(u16)))

@(require_results)
gfx_init :: proc(gfx: ^Gfx, frame: ^Frame) -> bool {
	ctx, clay_mem := clay_init(frame)
	if ctx == nil || clay_mem == nil {
		fmt.eprintln("failed to initialize clay")
		return false
	}
	gfx.clay_ctx = ctx
	gfx.clay_mem = clay_mem
	return true
}

gfx_shutdown :: proc(gfx: ^Gfx) {
	clay_shutdown(gfx)
}

gfx_reload :: proc(mem: ^Gfx, asts: ^assets.Assets) {
	assert(mem != nil, "Cannot reload GFX; memory is nil")
	clay_reload(mem.clay_ctx, asts)
}

gfx_frame_begin :: proc(frame: ^Frame) {
	sdl.SetRenderDrawColor(frame.device.renderer, 0, 0, 0, 255)

	clear_ok := sdl.RenderClear(frame.device.renderer)
	if !clear_ok do fmt.eprintln("failed to clear frame")

	clay_frame_begin(frame)
}

gfx_frame_end :: proc(frame: ^Frame) {
	clay_frame_end(frame)
	present_ok := sdl.RenderPresent(frame.device.renderer)
	if !present_ok do fmt.eprintln("failed to present frame")
}
