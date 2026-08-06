package app

import "../platform"
import "base:runtime"
import "core:fmt"
import sdl "vendor:sdl3"

// Frames owed after last input. Clay uses several frames for hover/scroll, one event
// needs a short burst of frames over exactly one.
FRAMES_AFTER_INPUT :: 3

// Idle wake cap. Used to ensure wake never leaves window frozen & room for slow work (cursor blink)
IDLE_TIMEOUT_MS :: 100

// Longest dt any consumer sees. Event driven means the gap since last draw frame is unbounded;
// scroll animation must not integrate across an idle period.
DT_MAX: f32 : 1.0 / 15.0

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
	rendering:    bool,
	flags:        App_Flags,
	input:        platform.Input,
	assets:       Assets,
	gfx:          Gfx,
	editor:       Editor,
	project:      Project,
	ui:           Ui,
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

	assets_ok := assets_load(&app.assets, device)
	if !assets_ok {
		fmt.println("Failed to load app assets")
		return false
	}

	frame := frame_make(app, device, {f32(w), f32(h)})
	gfx_ok := gfx_init(&app.gfx, &frame)
	if !gfx_ok {
		fmt.eprintln("Failed to initialize gfx")
		return false
	}

	ui_ok := ui_init(&app.ui)
	if !ui_ok {
		fmt.eprintln("Failed to initialize core ui")
		return false
	}

	editor_ok := editor_init(&app.editor, &app.project)
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
		for sdl.PollEvent(&event) {
			platform.input_event_process(&app.input, &event)
		}
		app.frames_owed = FRAMES_AFTER_INPUT
	} else if app.ui.focused != "" {
		// No input this wake, but a text field has focus and its caret needs
		// to keep blinking - render this idle tick too instead of freezing
		// mid-blink. Stops the moment focus clears, back to full idle.
		app.frames_owed = 1
	}

	if app.input.scale_changed {
		if !platform.device_refresh_scale(device) {
			fmt.eprintln("Failed to refresh device scale")
		}
		app.flags += {.Should_Reload_Assets}
	}

	if app.input.quit do app.flags += {.Should_Shutdown}
	when ODIN_DEBUG {
		if platform.key_pressed(&app.input, .F5) do app.flags += {.Should_Reload}
		if platform.key_pressed(&app.input, .F6) do app.flags += {.Should_Restart}
	}


	if app.flags & {.Should_Reload_Assets, .Should_Reload_Clay} != {} {
		if !app_reload_subsystems(device) do app.flags += {.Should_Shutdown}
		app.frames_owed = FRAMES_AFTER_INPUT
	}

	if app.frames_owed == 0 do return
	app.frames_owed -= 1
	app_render(device)
}

@(private = "file")
app_render :: proc(device: ^platform.Device) {
	// RenderPresent pumps events, which can re-enter here via the resize watch.
	// A nested clay.BeginLayout corrupts the command buffer.
	if app.rendering do return
	app.rendering = true
	defer app.rendering = false

	now_ns := sdl.GetTicksNS()
	app.dt = min(f32(now_ns - app.time_prev_ns) / 1_000_000_000.0, DT_MAX)
	app.time_prev_ns = now_ns

	w_px, h_px, size_ok := platform.render_output_size(device)
	if !size_ok {
		fmt.eprintln("Failed to query render output size")
		return
	}
	scale := app.assets.scale
	assert(scale > 0)
	w := f32(w_px) / scale
	h := f32(h_px) / scale

	frame := frame_make(app, device, {w, h})
	ctx := ctx_make(&app.ui, &frame)

	platform.reposition_traffic_lights(device.window, TOOLBAR_HEIGHT)

	gfx_frame_begin(&frame)
	ui_frame_start(&ctx)
	ui_update(&ctx)
	editor_frame(&app.editor, &ctx)
	ui_frame_end(&ctx)
	gfx_frame_end(&frame)

	when ODIN_DEBUG {
		if app.input.text.dropped > 0 {
			fmt.eprintfln("[input] dropped %d events this frame", app.input.text.dropped)
		}
	}
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
	// TODO: Check for unsaved project, pause close until saved or force close
	editor_shutdown(&app.editor)
	ui_shutdown(&app.ui, app.device)
	gfx_shutdown(&app.gfx)
	assets_unload(&app.assets)
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
	device := new(platform.Device, context.allocator)
	device_ok := platform.device_create(
		device,
		WINDOW_TITLE,
		WINDOW_WIDTH,
		WINDOW_HEIGHT,
		TOOLBAR_HEIGHT,
	)
	if !device_ok do return nil
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
		if !gfx_reload(&app.gfx, &app.assets, {f32(w), f32(h)}) do return false
	}

	if .Should_Reload_Assets in app.flags {
		app.flags -= {.Should_Reload_Assets}

		text_cache_clear(&app.gfx.text_cache)

		assets_unload(&app.assets)
		if !assets_load(&app.assets, device) {
			fmt.eprintln("Failed to reload assets")
			return false
		}
	}
	return true
}

@(private = "file")
frame_make :: proc(app: ^App, device: ^platform.Device, screen: [2]f32) -> Frame {
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
ctx_make :: proc(u: ^Ui, frame: ^Frame) -> Ctx {
	return {ui = u, frame = frame}
}
