package app

import "../../vendor/clay"
import "../platform"
import "core:fmt"
import sdl "vendor:sdl3"

Gfx :: struct {
	clay_ctx:      ^clay.Context,
	clay_mem:      [^]u8,
	clay_mem_size: u32,
	text_cache:    Text_Cache,
	interaction:   Interaction,
}

Frame :: struct {
	gfx:    ^Gfx,
	device: ^platform.Device,
	assets: ^Assets,
	input:  ^platform.Input,
	screen: [2]f32,
	dt:     f32,
	cursor: platform.Cursor,
}

#assert(len(Text) <= int(max(u16)))

@(require_results)
gfx_init :: proc(gfx: ^Gfx, frame: ^Frame) -> bool {
	ctx, clay_mem := clay_init(frame)
	if ctx == nil || clay_mem == nil {
		fmt.eprintln("failed to initialize clay")
		return false
	}
	gfx.clay_ctx = ctx
	gfx.clay_mem = clay_mem
	gfx.clay_mem_size = clay.MinMemorySize()
	return true
}

gfx_shutdown :: proc(gfx: ^Gfx) {
	text_cache_clear(&gfx.text_cache)
	clay_shutdown(gfx)
}

@(require_results)
gfx_reload :: proc(gfx: ^Gfx, asts: ^Assets, size: [2]f32) -> bool {
	assert(gfx != nil)
	if !clay_reload(gfx, asts, size) {
		fmt.eprintln("Failed to reload clay; press F6 to restart")
		return false
	}
	return true
}

gfx_frame_begin :: proc(frame: ^Frame) {
	sdl.SetRenderDrawColor(frame.device.renderer, 18, 18, 18, 255)

	clear_ok := sdl.RenderClear(frame.device.renderer)
	if !clear_ok do fmt.eprintln("failed to clear frame")

	clay_frame_begin(frame)
}

gfx_frame_end :: proc(frame: ^Frame) {
	clay_frame_end(frame)
	text_cache_frame_end(&frame.gfx.text_cache)
	platform.cursor_apply(frame.device, frame.cursor)
	present_ok := sdl.RenderPresent(frame.device.renderer)
	if !present_ok do fmt.eprintln("failed to present frame")
}
