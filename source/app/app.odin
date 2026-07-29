package app

import assets "../assets"
import gfx "../gfx"
import platform "../platform"
import "base:runtime"
import "core:fmt"
import sdl "vendor:sdl3"


// Define unused var to access runtime, it will only be loaded in ODIN_DEBUG mode
@(private)
_ :: runtime.Type_Info

App_Flag :: enum u8 {
	Should_Shutdown,
	Force_Restart,
	Force_Reload,
}
App_Flags :: distinct bit_set[App_Flag;u8]

App :: struct {
	time_prev_ns: u64,
	dt:           f32,
	flags:        App_Flags,
	input:        platform.Input,
	assets:       assets.Assets,
	gfx:          gfx.Gfx,
	// ui:           ui.State,
}
mem: ^App

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
app_init :: proc(device: ^platform.Device) {
	mem = new(App_Memory, context.allocator)

	w, h := platform.output_size(device)
	if w <= 0 || h <= 0 {
		fmt.eprint("Renderer output size has a 0 value")
	}
	mem.gfx_mem = gfx.gfx_init({w, h}, mem.renderer)

	mem.time_prev_ns = sdl.GetTicksNS()
}

@(export)
app_update :: proc(device: ^platform.Device) {
	when ODIN_DEBUG {
		mem.flags -= {.Force_Restart, .Force_Reload}
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
	if mem.input.quit do mem.flags += {.Should_Shutdown}
	when ODIN_DEBUG {
		if platform.key_pressed(&mem.input, .F5) do mem.force_reload = true
		if platform.key_pressed(&mem.input, .F6) do mem.force_restart = true
	}

	w, h := platform.output_size(device)
	if w <= 0 || h <= 0 {
		fmt.eprint("Renderer output size has a 0 value")
	}
	frame := gfx.Frame { 	// <- lives here, on app_update's stack
		device = device,
		assets = &mem.assets,
		input  = &mem.input,
		screen = {f32(w), f32(h)},
		dt     = mem.dt,
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
	mem := (^App_Memory)(m)
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

@(export)
app_device_create :: proc() -> ^platform.Device {
	device := platform.device_create()
	assert(device != nil, "Failed to create platform device")
	return device
}

@(export)
app_device_destroy :: proc(device: ^platform.Device) {
	device := cast(^platform.Device)device
	platform.device_destroy(device)
}
