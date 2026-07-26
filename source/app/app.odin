package app

import platform "../platform"
import "base:runtime"
import "core:fmt"
import sdl "vendor:sdl3"

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
}

@(export)
app_update :: proc() {
	mem.force_reload = false
	mem.force_restart = false

	event: sdl.Event
	poll: for sdl.PollEvent(&event) {
		#partial switch event.type {
		case .QUIT:
			mem.should_shutdown = true
			break poll
		case .KEY_DOWN:
			if event.key.repeat do break
			#partial switch event.key.scancode {
			case .F5:
				mem.force_reload = true
			case .F6:
				mem.force_restart = true
			}
		}
	}
}

@(export)
app_shutdown :: proc() {
	if mem == nil do return
	free(mem)
	mem = nil
}

@(export)
app_memory :: proc() -> rawptr {
	return mem
}

@(export)
app_hot_reloaded :: proc(m: rawptr) {
	mem = (^App_Memory)(m)

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
		sdl.DestroyWindow(window)
		sdl.Quit()
	}
}
