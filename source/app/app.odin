package app

import "../assets"
import "../config"
import "../editor"
import "../editor/editor_types"
import "../gfx"
import "../platform"
import "../project"
import "../ui"
import "base:runtime"
import "core:fmt"
import "core:mem"
import sdl "vendor:sdl3"

// Frames owed after last input. Clay uses several frames for hover/scroll, one event
// needs a short burst of frames over exactly one.
FRAMES_AFTER_INPUT :: 3

// Idle wake cap. Used to ensure wake never leaves window frozen & room for slow work (cursor blink)
IDLE_TIMEOUT_MS :: 100

// Longest dt any consumer sees. Event driven means the gap since last draw frame is unbounded;
// scroll animation must not integrate across an idle period.
DT_MAX: f32 : 1.0 / 15.0

// Define unused var to access runtime, it will only be loaded in ODIN_DEBUG mode
@(private)
_ :: runtime.Type_Info

App_Flag :: enum u8 {
	Should_Shutdown,
	Should_Restart,
	Should_Reload,
	Should_Reload_Assets,
	Should_Reload_Clay,
}
App_Flags :: distinct bit_set[App_Flag;u8]

App :: struct {
	// Borrowed from the host, survives reloads. Stashed so the resize-watch
	// render callback can find it without a userdata plumbing round-trip.
	device:       ^platform.Device,
	time_prev_ns: u64,
	dt:           f32,
	frames_owed:  int,
	flags:        App_Flags,
	input:        platform.Input,
	assets:       assets.Assets,
	gfx:          gfx.Gfx,
	editor:       editor_types.Editor,
	project:      project.Project,
	ui:           ui.Ui,
}
app: ^App

@(export, require_results)
app_init :: proc(device: ^platform.Device) -> bool {
	app = new(App, context.allocator)
	app.device = device

	w, h, size_ok := platform.window_size(device)
	if !size_ok {
		fmt.eprintln("Failed to compute output size on device")
		return false
	}

	assets_ok := assets.assets_load(&app.assets, device)
	if !assets_ok {
		fmt.println("Failed to load app assets")
		return false
	}

	frame := frame_make(app, device, {f32(w), f32(h)})
	gfx_ok := gfx.gfx_init(&app.gfx, &frame)
	if !gfx_ok {
		fmt.eprintln("Failed to initialize gfx")
		return false
	}

	ui_ok := ui.ui_init(&app.ui)
	if !ui_ok {
		fmt.eprintln("Failed to initialize core ui")
		return false
	}

	editor_ok := editor.editor_init(&app.editor)
	if !editor_ok {
		fmt.eprintln("Failed to initialize the editor")
		return false
	}

	app.time_prev_ns = sdl.GetTicksNS()

	// Paired with re-register in app_hot_reloaded (Appendix A rule 6).
	platform.window_set_render_callback(app_render_c)

	return true
}

@(export)
app_update :: proc(device: ^platform.Device) {
	when ODIN_DEBUG {
		app.flags -= {.Should_Reload, .Should_Restart}
	}

	platform.input_frame_begin(&app.input)

	// Block until event, on mid-burst we poll (timeout 0) so burst runs at display rate;
	// idle we sleep and wake at most 10 times a second.
	timeout := i32(0) if app.frames_owed > 0 else i32(IDLE_TIMEOUT_MS)

	event: sdl.Event
	if sdl.WaitEventTimeout(&event, timeout) {
		platform.input_event_process(&app.input, &event)
		// Drain queue in frame: act in bulk  to never react in mid-render.
		for sdl.PollEvent(&event) {
			platform.input_event_process(&app.input, &event)
		}
		app.frames_owed = FRAMES_AFTER_INPUT
	}

	if app.input.scale_changed {
		if !platform.device_refresh_scale(device) {
			fmt.eprintln("Failed to refresh device scale")
		}
		// Reload assets, as fonts rely on scale
		app.flags += {.Should_Reload_Assets}
	}

	if app.input.quit do app.flags += {.Should_Shutdown}
	when ODIN_DEBUG {
		if platform.key_pressed(&app.input, .F5) do app.flags += {.Should_Reload}
		if platform.key_pressed(&app.input, .F6) do app.flags += {.Should_Restart}
	}

	// A reload changes the code == stale screen; must reload

	if app.flags & {.Should_Reload_Assets, .Should_Reload_Clay} != {} {
		if !app_reload_subsystems(device) do app.flags += {.Should_Shutdown}
		app.frames_owed = FRAMES_AFTER_INPUT
	}

	// No change or owes: don't touch GPU.
	if app.frames_owed == 0 do return
	app.frames_owed -= 1
	app_render(device)
}

// Pure render path. No SDL polling, no flag mutation. Safe to call from the
// resize watch as well as app_update.
@(private = "file")
app_render :: proc(device: ^platform.Device) {
	now_ns := sdl.GetTicksNS()
	app.dt = min(f32(now_ns - app.time_prev_ns) / 1_000_000_000.0, DT_MAX)
	app.time_prev_ns = now_ns

	// Lay out to the drawable, not the window; the two disagree mid live-resize.
	w_px, h_px, size_ok := platform.render_output_size(device)
	if !size_ok {
		fmt.eprintln("Failed to query render output size")
		return
	}
	scale := app.assets.scale
	assert(scale > 0) // divide-by-zero would collapse the clay layout to +Inf.
	w := f32(w_px) / scale
	h := f32(h_px) / scale

	frame := frame_make(app, device, {w, h})
	ctx := ctx_make(&app.ui, &frame)

	platform.reposition_traffic_lights(device.window, config.TOOLBAR_HEIGHT)

	gfx.gfx_frame_begin(&frame)
	ui.ui_frame_start(&ctx)
	editor.editor_frame(&app.editor, &ctx)
	ui.ui_frame_end(&app.ui)
	gfx.gfx_frame_end(&frame)
}

// C-ABI trampoline for the resize watch. Runs with default_context, so
// context.allocator is not the host's tracking allocator: keep the render
// path allocation-free.
@(private = "file")
app_render_c :: proc "c" () {
	context = runtime.default_context()
	if app == nil || app.device == nil do return
	app_render(app.device)
	free_all(context.temp_allocator)
}

@(export)
app_shutdown :: proc() {
	if app == nil do return
	editor.editor_shutdown(&app.editor)
	ui.ui_shutdown(&app.ui)
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
app_hot_reloaded :: proc(m: rawptr, assets_changed: bool) {
	app = (^App)(m)
	app.flags += {.Should_Reload_Clay}
	if assets_changed do app.flags += {.Should_Reload_Assets}
	// Repoint SDL at this module's callback address (Appendix A rule 6).
	platform.window_set_render_callback(app_render_c)
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

// Returns false when app cannot draw
@(require_results)
app_reload_subsystems :: proc(device: ^platform.Device) -> bool {
	if .Should_Reload_Clay in app.flags {
		app.flags -= {.Should_Reload_Clay}

		w, h, size_ok := platform.window_size(device)
		if !size_ok {
			fmt.eprintln("Failed to query window size during clay reload")
			return false
		}

		// Reload gfx since to set new measure text and error handler callbacks for clay
		if !gfx.gfx_reload(&app.gfx, &app.assets, {f32(w), f32(h)}) do return false
	}

	if .Should_Reload_Assets in app.flags {
		app.flags -= {.Should_Reload_Assets}

		gfx.text_cache_clear(&app.gfx.text_cache)

		assets.assets_unload(&app.assets)
		if !assets.assets_load(&app.assets, device) {
			fmt.eprintln("Failed to reload assets")
			return false
		}
	}
	return true
}

@(private = "file")
frame_make :: proc(app: ^App, device: ^platform.Device, screen: [2]f32) -> gfx.Frame {
	return {
		gfx = &app.gfx,
		device = device,
		assets = &app.assets,
		input = &app.input,
		screen = screen,
		dt = app.dt,
	}
}

@(private = "file")
ctx_make :: proc(u: ^ui.Ui, frame: ^gfx.Frame) -> ui.Ctx {
	return {ui = u, frame = frame}
}

when ODIN_DEBUG {
	@(export)
	app_memory_layout_hash :: proc() -> u64 {
		FNV_OFFSET :: u64(1469598103934665603)
		seen := make(map[typeid]bool, 64, context.temp_allocator) // host will free each loop
		h := layout_hash(type_info_of(App), FNV_OFFSET, &seen)
		return layout_hash(type_info_of(platform.Device), h, &seen)
	}

	@(export)
	app_assets_table_hash :: proc() -> u64 {
		FNV_OFFSET :: u64(1469598103934665603)
		FNV_PRIME :: u64(1099511628211)
		h := FNV_OFFSET
		for b in mem.byte_slice(&assets.text_styles, size_of(assets.text_styles)) {
			h = (h ~ u64(b)) * FNV_PRIME
		}
		for b in mem.byte_slice(&assets.font_paths, size_of(assets.font_paths)) {
			h = (h ~ u64(b)) * FNV_PRIME
		}
		for b in mem.byte_slice(&assets.texture_paths, size_of(assets.texture_paths)) {
			h = (h ~ u64(b)) * FNV_PRIME
		}
		return h
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
