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
	if gfx == nil do return
	if gfx.clay_mem != nil do free(gfx.clay_mem)
	if gfx.clay_ctx != nil do free(gfx.clay_ctx)
	free(gfx)
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
	commands := clay.EndLayout(frame.dt)
	clay_render_commands(&commands, frame)
}
