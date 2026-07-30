package gfx

import clay "../../vendor/clay"
import "core:fmt"

Gfx :: struct {
	clay_ctx: ^clay.Context,
	clay_mem: [^]u8,
}

@(require_results)
gfx_init :: proc(gfx: ^Gfx, size: [2]i32, frame: ^Frame) -> bool {
	ctx, clay_mem := clay_init(frame)
	if ctx == nil || clay_mem == nil {
		fmt.eprint("failed to initialize clay")
		return false
	}
	gfx.clay_ctx = ctx
	gfx.clay_mem = clay_mem
	return true
}

gfx_shutdown :: proc(gfx: ^Gfx) {
	clay_shutdown(gfx)
}

gfx_reload :: proc(mem: ^Gfx) {
	assert(mem != nil, "Cannot reload GFX; memory is nil")
	clay_reload(mem.clay_ctx)
	// reload textures and fonts
}

gfx_frame_begin :: proc(gfx: ^Gfx, frame: ^Frame) {
	// reset cursor
	clay_frame_begin(frame)
}

gfx_frame_end :: proc(frame: ^Frame) {
	clay_frame_end(frame)
}
