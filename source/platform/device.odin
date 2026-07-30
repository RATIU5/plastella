package platform

import conf "../config"
import "core:fmt"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

Device :: struct {
	window:      ^sdl.Window,
	renderer:    ^sdl.Renderer,
	text_engine: ^ttf.TextEngine,
	scale:       f32,
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
	window := sdl.CreateWindow(conf.WINDOW_TITLE, conf.WINDOW_WIDTH, conf.WINDOW_HEIGHT, FLAGS)
	if window == nil do return false

	renderer := sdl.CreateRenderer(window, nil)
	if renderer == nil do return false

	d := sdl.GetWindowPixelDensity(window)
	sdl.SetRenderScale(renderer, d, d)
	device.scale = d

	ow, oh: i32
	sdl.GetRenderOutputSize(renderer, &ow, &oh)
	ww, wh: i32
	sdl.GetWindowSize(window, &ww, &wh)
	fmt.eprintfln("density=%.2f window=%dx%d output=%dx%d", d, ww, wh, ow, oh)

	text_engine := ttf.CreateRendererTextEngine(renderer)
	if text_engine == nil do return false

	// Configure & show window AFTER setting up renderer and text engine
	window_configure(window)

	device.window = window
	device.renderer = renderer
	device.text_engine = text_engine

	return true
}

device_destroy :: proc(device: ^Device) {
	if device != nil {
		sdl.DestroyRenderer(device.renderer)
		sdl.DestroyWindow(device.window)
		sdl.Quit()
		ttf.Quit()
	}
}

@(require_results)
output_size :: proc(device: ^Device) -> (i32, i32, bool) {
	w, h: i32
	ok := sdl.GetWindowSize(device.window, &w, &h)
	return w, h, ok
}

@(private = "file", require_results)
sdl_init :: proc() -> bool {

	if !ttf.Init() {
		fmt.eprintln("Failed to initialize TTF")
		return false
	}

	FLAGS :: sdl.InitFlags{.VIDEO}

	if !sdl.Init(FLAGS) {
		fmt.eprintfln("SDL Error: %s\n", sdl.GetError())
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
