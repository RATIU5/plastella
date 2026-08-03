package platform

import conf "../config"
import "core:fmt"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"

Device :: struct {
	window:         ^sdl.Window,
	renderer:       ^sdl.Renderer,
	text_engine:    ^ttf.TextEngine,
	scale:          f32,
	cursors:        [Cursor]^sdl.Cursor,
	cursor_current: Cursor,
}

@(require_results)
device_create :: proc(device: ^Device) -> bool {
	if init_ok := sdl_init(); !init_ok do return false

	FLAGS :: sdl.WindowFlags {
		.RESIZABLE,
		.HIGH_PIXEL_DENSITY,
		// Hide window and show it after it's been configured to avoid white flash
		.HIDDEN,
	}
	device.window = sdl.CreateWindow(
		conf.WINDOW_TITLE,
		conf.WINDOW_WIDTH,
		conf.WINDOW_HEIGHT,
		FLAGS,
	)
	if device.window == nil {
		device_destroy(device)
		return false
	}

	device.renderer = sdl.CreateRenderer(device.window, nil)
	if device.renderer == nil {
		device_destroy(device)
		return false
	}

	sdl.SetRenderVSync(device.renderer, 1)

	// No SetRenderScale: clay lays out in logical px, and clay_render_commands
	// converts to physical. Setting scale here would apply it twice.
	d := sdl.GetWindowPixelDensity(device.window)
	device.scale = d

	device.text_engine = ttf.CreateRendererTextEngine(device.renderer)
	if device.text_engine == nil {
		device_destroy(device)
		return false
	}

	for kind, cursor in cursor_sdl_kind {
		device.cursors[cursor] = sdl.CreateSystemCursor(kind)
		if device.cursors[cursor] == nil {
			device_destroy(device)
			return false
		}
	}

	// Configure & show window AFTER setting up renderer and text engine
	window_configure(device.window)

	return true
}

device_destroy :: proc(device: ^Device) {
	if device != nil {
		window_teardown()
		for c in device.cursors {
			if c != nil do sdl.DestroyCursor(c)
		}
		if device.text_engine != nil do ttf.DestroyRendererTextEngine(device.text_engine)
		if device.renderer != nil do sdl.DestroyRenderer(device.renderer)
		if device.window != nil do sdl.DestroyWindow(device.window)
		ttf.Quit()
		sdl.Quit()
	}
}

@(require_results)
device_refresh_scale :: proc(device: ^Device) -> bool {
	d := sdl.GetWindowPixelDensity(device.window)
	if d <= 0 do return false
	device.scale = d
	return true
}

@(require_results)
window_size :: proc(device: ^Device) -> (i32, i32, bool) {
	w, h: i32
	ok := sdl.GetWindowSize(device.window, &w, &h)
	return w, h, ok
}

// Drawable size in pixels of the current render target. Prefer this over
// window_size in the render path so clay lays out at exactly the size Metal
// will present into; during live resize the two can transiently disagree.
@(require_results)
render_output_size :: proc(device: ^Device) -> (i32, i32, bool) {
	w, h: i32
	ok := sdl.GetCurrentRenderOutputSize(device.renderer, &w, &h)
	return w, h, ok
}

@(private = "file", require_results)
sdl_init :: proc() -> bool {
	FLAGS :: sdl.InitFlags{.VIDEO}
	if !sdl.Init(FLAGS) {
		fmt.eprintfln("SDL Error: %s\n", sdl.GetError())
		return false
	}

	if !ttf.Init() {
		fmt.eprintln("Failed to initialize TTF")
		return false
	}
	return true
}

@(private = "file")
window_configure :: proc(window: ^sdl.Window) {
	if window != nil {
		// Will "jump" to center, but hidden will fix that
		sdl.SetWindowPosition(window, sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED)
		sdl.SetWindowMinimumSize(window, 800, 600)
		window_setup(window, conf.TOOLBAR_HEIGHT)
		sdl.ShowWindow(window)
	}
}
