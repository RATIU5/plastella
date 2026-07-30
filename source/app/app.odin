package app

import assets "../assets"
import editor "../editor"
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
	Should_Restart,
	Should_Reload,
	Should_Reload_Assets,
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
app: ^App

@(export, require_results)
app_init :: proc(device: ^platform.Device) -> bool {
	app = new(App, context.allocator)

	w, h, size_ok := platform.output_size(device)
	if !size_ok {
		fmt.eprintln("Failed to compute output size on device")
		return false
	}

	assets_ok := assets.assets_load(&app.assets, device)
	if !assets_ok {
		fmt.println("Failed to load app assets")
		return false
	}

	frame := gfx.Frame {
		device = device,
		assets = &app.assets,
		input  = &app.input,
		screen = {f32(w), f32(h)},
		dt     = app.dt,
	}
	gfx_ok := gfx.gfx_init(&app.gfx, {w, h}, &frame)
	if !gfx_ok {
		fmt.eprintln("Failed to initialize gfx")
		return false
	}

	editor_ok := editor.editor_init()
	if !editor_ok {
		fmt.eprintln("Failed to initialize the editor")
		return false
	}

	app.time_prev_ns = sdl.GetTicksNS()

	return true
}

@(export)
app_update :: proc(device: ^platform.Device) {
	when ODIN_DEBUG {
		app.flags -= {.Should_Reload, .Should_Restart}
		if .Should_Reload_Assets in app.flags {
			app.flags -= {.Should_Reload_Assets}
			assets.assets_unload(&app.assets)
			if !assets.assets_load(&app.assets, device) do app.flags += {.Should_Shutdown}
		}
	}

	// Delta time computation
	now_ns := sdl.GetTicksNS()
	app.dt = f32(now_ns - app.time_prev_ns) / 1_000_000_000.0 // ns -> secs
	app.time_prev_ns = now_ns

	// Process inputs
	platform.input_frame_begin(&app.input)
	event: sdl.Event
	poll: for sdl.PollEvent(&event) {
		platform.input_event_process(&app.input, &event)
	}
	if app.input.quit do app.flags += {.Should_Shutdown}
	when ODIN_DEBUG {
		if platform.key_pressed(&app.input, .F5) do app.flags += {.Should_Reload}
		if platform.key_pressed(&app.input, .F6) do app.flags += {.Should_Restart}
	}

	w, h, size_ok := platform.output_size(device)
	if !size_ok {
		fmt.eprintln("Failed to compute output size on device; defaulting to 0x0")
		w, h = 0, 0
	}
	frame := gfx.Frame {
		device = device,
		assets = &app.assets,
		input  = &app.input,
		screen = {f32(w), f32(h)},
		dt     = app.dt,
	}

	gfx.gfx_frame_begin(&app.gfx, &frame)
	editor.editor_frame(&frame)
	gfx.gfx_frame_end(&frame)
}

@(export)
app_shutdown :: proc() {
	if app == nil do return
	editor.editor_shutdown()
	gfx.gfx_shutdown(&app.gfx)
	assets.assets_unload(&app.assets)
	free(app)
	app = nil
}

@(export)
app_memory :: proc() -> rawptr {
	return app
}

@(export)
app_hot_reloaded :: proc(m: rawptr) {
	app = (^App)(m)
	gfx.gfx_reload(&app.gfx, &app.assets)
	app.flags += {.Should_Reload_Assets}
}

@(export)
app_should_run :: proc() -> bool {
	return .Should_Shutdown not_in app.flags
}

@(export)
app_force_reload :: proc() -> bool {
	return .Should_Reload in app.flags
}

@(export)
app_force_restart :: proc() -> bool {
	return .Should_Restart in app.flags
}

@(export)
app_memory_size :: proc() -> int {
	return size_of(App)
}

@(export)
app_device_create :: proc() -> ^platform.Device {
	device := new(platform.Device)
	if device_ok := platform.device_create(device); !device_ok do return nil
	return device
}

@(export)
app_device_destroy :: proc(device: ^platform.Device) {
	platform.device_destroy(device)
	free(device)
}

when ODIN_DEBUG {
	@(export)
	app_memory_layout_hash :: proc() -> u64 {
		FNV_OFFSET :: u64(1469598103934665603)
		seen := make(map[typeid]bool, 64, context.temp_allocator) // host will free each loop
		h := layout_hash(type_info_of(App), FNV_OFFSET, &seen)
		return layout_hash(type_info_of(platform.Device), h, &seen)
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
