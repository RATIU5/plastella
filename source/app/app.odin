package app

import gfx "../gfx"
import platform "../platform"
import "base:runtime"
import "core:fmt"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"

WINDOW_TITLE :: "Plastella"
WINDOW_WIDTH :: 960
WINDOW_HEIGHT :: 540

// Define unused var to access runtime, it will only be loaded in ODIN_DEBUG mode
@(private)
_ :: runtime.Type_Info

App_Memory :: struct {
	should_shutdown: bool,
	force_reload:    bool,
	force_restart:   bool,
	time_prev_ns:    u64,
	dt:              f32,
	input:           platform.Input,
	renderer:        ^sdl.Renderer,
	gfx_mem:         ^gfx.Gfx_Memory,
}
mem: ^App_Memory

when ODIN_DEBUG {
	@(export)
	app_memory_layout_hash :: proc() -> u64 {
		FNV_OFFSET :: u64(1469598103934665603)
		seen := make(map[typeid]bool, 64, context.temp_allocator) // host will free each loop
		return layout_hash(type_info_of(App_Memory), FNV_OFFSET, &seen)
	}

	layout_hash :: proc(ti: ^runtime.Type_Info, seed: u64, seen: ^map[typeid]bool) -> u64 {
		PRIME :: u64(1099511628211)
		if ti == nil do return seed // rawptr elem, empty proc results, etc.
		h := (seed ~ u64(ti.size)) * PRIME
		if seen[ti.id] do return h // already walked this type
		seen[ti.id] = true

		#partial switch v in ti.variant {
		case runtime.Type_Info_Named:
			h = layout_hash(v.base, h, seen)
		case runtime.Type_Info_Struct:
			for i in 0 ..< int(v.field_count) {
				h = (h ~ u64(v.offsets[i])) * PRIME
				h = layout_hash(v.types[i], h, seen)
			}
		case runtime.Type_Info_Union:
			for variant in v.variants do h = layout_hash(variant, h, seen)
		case runtime.Type_Info_Array:
			h = layout_hash(v.elem, h, seen)
		case runtime.Type_Info_Enumerated_Array:
			h = layout_hash(v.elem, h, seen)
		case runtime.Type_Info_Slice:
			h = layout_hash(v.elem, h, seen)
		case runtime.Type_Info_Dynamic_Array:
			h = layout_hash(v.elem, h, seen)
		case runtime.Type_Info_Map:
			h = layout_hash(v.key, h, seen)
			h = layout_hash(v.value, h, seen)
		case runtime.Type_Info_Pointer:
			h = layout_hash(v.elem, h, seen) // nil for rawptr -> stops
		case runtime.Type_Info_Multi_Pointer:
			h = layout_hash(v.elem, h, seen)
		}
		return h
	}
}

@(export)
app_init :: proc(window: ^sdl.Window) {
	assert(window != nil, "app_init: window is nil")
	mem = new(App_Memory, context.allocator)

	// SDL Renderer memory
	mem.renderer = sdl.GetRenderer(window)
	assert(mem.renderer != nil, "cannot get renderer from window")

	// Gfx_Memory (and clay memory)
	w, h: i32
	size_ok := sdl.GetRenderOutputSize(mem.renderer, &w, &h)
	assert(size_ok, cast(string)sdl.GetError())
	mem.gfx_mem = gfx.gfx_init({w, h})

	mem.time_prev_ns = sdl.GetTicksNS()
}

@(export)
app_update :: proc() {
	when ODIN_DEBUG {
		mem.force_reload = false
		mem.force_restart = false
	}

	// Delta time computation
	now_ns := sdl.GetTicksNS()
	mem.dt = f32(now_ns - mem.time_prev_ns) / 1_000_000_000.0 // ns -> secs
	mem.time_prev_ns = now_ns

	// Process inputs
	platform.input_frame_begin(&mem.input)
	event: sdl.Event
	poll: for sdl.PollEvent(&event) {
		platform.input_event_process(&mem.input, &event)
	}
	if mem.input.quit do mem.should_shutdown = true
	when ODIN_DEBUG {
		if platform.key_pressed(&mem.input, .F5) do mem.force_reload = true
		if platform.key_pressed(&mem.input, .F6) do mem.force_restart = true
	}

	// Process graphics frame
	gfx.gfx_frame_begin(
		mem.gfx_mem,
		mem.renderer,
		mem.input.mouse.pos,
		platform.mouse_down(&mem.input, .Left),
		platform.mouse_scroll(&mem.input),
		mem.dt,
	)

	gfx.gfx_frame_end(mem.gfx_mem, mem.dt)
}

@(export)
app_shutdown :: proc() {
	if mem == nil do return

	// Gfx_Memory
	gfx.gfx_shutdown(mem.gfx_mem)
	mem.gfx_mem = nil

	// App_Memory
	free(mem)
	mem = nil
}

@(export)
app_memory :: proc() -> rawptr {
	return mem
}

@(export)
app_hot_reloaded :: proc(m: rawptr) {
	new_mem := (^App_Memory)(m)
	mem.renderer = new_mem.renderer
	mem.gfx_mem = new_mem.gfx_mem
}

@(export)
app_should_run :: proc() -> bool {
	return !mem.should_shutdown
}

@(export)
app_force_reload :: proc() -> bool {
	return mem.force_reload
}

@(export)
app_force_restart :: proc() -> bool {
	return mem.force_restart
}

@(export)
app_memory_size :: proc() -> int {
	return size_of(App_Memory)
}

/*
	Calls sdl.Init() then returns a newly created Plastella window

	Returns:
	- The sdl window pointer
*/
@(export)
app_window_create :: proc() -> ^sdl.Window {
	if !ttf.Init() {
		fmt.eprint("Failed to initialize TTF")
	}

	if !sdl.Init({.VIDEO}) {
		fmt.eprintf("SDL Error: %s\n", sdl.GetError())
		return nil
	}

	window := sdl.CreateWindow(
	WINDOW_TITLE,
	WINDOW_WIDTH,
	WINDOW_HEIGHT,
	{
		.RESIZABLE,
		.HIGH_PIXEL_DENSITY,
		// Hide window and show it after it's been configured to avoid white flash
		.HIDDEN,
	},
	)

	assert(window != nil, "failed to create window")

	// The renderer lives with the window (not app_init) so it survives hard
	// restarts; app_init re-fetches it with sdl.GetRenderer(window).
	renderer := sdl.CreateRenderer(window, nil)
	assert(renderer != nil, cast(string)sdl.GetError())

	if window != nil {
		// Will "jump" to center, but hidden will fix that
		sdl.SetWindowPosition(window, sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED)
		platform.setup_window(window)
		sdl.ShowWindow(window)
	}

	return window
}

/*
	Destroys the provided window if it exists, and then quits SDL

	Inputs:
	- window: pointer to sdl window to destroy
*/
@(export)
app_window_destroy :: proc(window: ^sdl.Window) {
	if window != nil {
		sdl.DestroyRenderer(sdl.GetRenderer(window))
		sdl.DestroyWindow(window)
		sdl.Quit()
		ttf.Quit()
	}
}
