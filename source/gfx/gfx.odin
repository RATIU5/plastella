package gfx

import clay "../../vendor/clay"
import "core:c"
import "core:fmt"
import sdl "vendor:sdl3"

Gfx_Memory :: struct {
	clay_trace:      ^Clay_Trace,
	clay_ctx:        ^clay.Context,
	clay_mem:        [^]u8,
	clay_render_mem: ^Clay_Render_Memory,
}

gfx_init :: proc(size: [2]i32) -> ^Gfx_Memory {
	mem := new(Gfx_Memory)

	// Clay Memory
	mem.clay_trace = new(Clay_Trace)
	ctx, clay_mem, render_mem := clay_init(size, mem.clay_trace)
	mem.clay_ctx = ctx
	mem.clay_mem = clay_mem
	mem.clay_render_mem = render_mem

	return mem
}

gfx_shutdown :: proc(mem: ^Gfx_Memory) {
	if mem == nil do return

	// Clay Memory
	if mem.clay_render_mem != nil do free(mem.clay_render_mem)
	if mem.clay_mem != nil do free(mem.clay_mem)
	if mem.clay_ctx != nil do free(mem.clay_ctx)
	if mem.clay_trace != nil do free(mem.clay_trace)

	free(mem)
}

gfx_reload :: proc(mem: ^Gfx_Memory) {
	assert(mem != nil, "Cannot reload GFX; memory is nil")
	clay_reload(mem.clay_ctx, mem.clay_render_mem)
	// reload textures and fonts
}

gfx_frame_begin :: proc(
	mem: ^Gfx_Memory,
	renderer: ^sdl.Renderer,
	mouse_pos: [2]f32,
	mouse_left: bool,
	mouse_scroll: [2]f32,
	dt: f32,
) {
	// reset cursor
	w, h: c.int
	dimensions_ok := sdl.GetRenderOutputSize(renderer, &w, &h)
	if !dimensions_ok {
		fmt.eprint("failed to get screen dimensions for gfx_frame_begin")
		return
	}
	dimensions := clay.Dimensions{cast(f32)w, cast(f32)h}

	clay_layout_begin(
		mem.clay_render_mem,
		mem.clay_trace,
		dimensions,
		mouse_pos,
		mouse_left,
		mouse_scroll,
		dt,
	)
}

gfx_frame_end :: proc(mem: ^Gfx_Memory, dt: f32) {
	commands := clay.EndLayout(dt)
	clay_render_commands(mem.clay_render_mem, &commands)
}
