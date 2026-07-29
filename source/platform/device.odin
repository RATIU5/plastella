package platform

import conf "../config"
import "core:fmt"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

Device :: struct {
	window:      ^sdl.Window,
	renderer:    ^sdl.Renderer,
	text_engine: ^ttf.TextEngine,
}

device_create :: proc() -> ^Device {
	init_ok := sdl_init()
	if !init_ok {
		return nil
	}

	FLAGS :: sdl.WindowFlags {
		.RESIZABLE,
		.HIGH_PIXEL_DENSITY,
		// Hide window and show it after it's been configured to avoid white flash
		.HIDDEN,
	}
	window := sdl.CreateWindow(conf.WINDOW_TITLE, conf.WINDOW_WIDTH, conf.WINDOW_HEIGHT, FLAGS)
	assert(window != nil, "failed to create window")

	renderer := sdl.CreateRenderer(window, nil)
	assert(renderer != nil, cast(string)sdl.GetError())

	text_engine := ttf.CreateRendererTextEngine(renderer)
	assert(text_engine != nil, "Failed to create text engine")

	// Configure & show window AFTER setting up renderer and text engine
	window_configure(window)

	device := new(Device)
	device.window = window
	device.renderer = renderer
	device.text_engine = text_engine

	return device
}

device_destroy :: proc(device: ^Device) {
	if device != nil {
		sdl.DestroyRenderer(device.renderer)
		sdl.DestroyWindow(device.window)
		sdl.Quit()
		ttf.Quit()
	}
}

output_size :: proc(device: ^Device) -> (w, h: i32) {
	temp_w, temp_h: i32 = 0, 0
	size_ok := sdl.GetRenderOutputSize(device.renderer, &w, &h)
	return temp_w, temp_h
}

@(private = "file", require_results)
sdl_init :: proc() -> bool {

	if !ttf.Init() {
		fmt.eprint("Failed to initialize TTF")
		return false
	}

	FLAGS :: sdl.InitFlags{.VIDEO}

	if !sdl.Init(FLAGS) {
		fmt.eprintf("SDL Error: %s\n", sdl.GetError())
		return false
	}

	return true
}

@(private = "file")
window_configure :: proc(window: ^sdl.Window) {
	if window != nil {
		// Will "jump" to center, but hidden will fix that
		sdl.SetWindowPosition(window, sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED)
		setup_window(window)
		sdl.ShowWindow(window)
	}
}
