package gfx

import clay "../../vendor/clay"

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
