package platform

import "core:fmt"
import "core:strconv"
import "core:strings"
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

// title/width/height/toolbar_height are app config, not platform's to own
// (ODIN_STYLE.md 3.1: platform stays Plastella-agnostic) - the caller supplies them.
WINDOW_MIN_W :: i32(560)
WINDOW_MIN_H :: i32(400)

@(require_results)
device_create :: proc(
	device: ^Device,
	title: cstring,
	width, height: i32,
	toolbar_height: f32,
) -> bool {
	if init_ok := sdl_init(); !init_ok do return false

	FLAGS :: sdl.WindowFlags {
		.RESIZABLE,
		.HIGH_PIXEL_DENSITY,
		// Hide window and show it after it's been configured to avoid white flash
		.HIDDEN,
	}
	device.window = sdl.CreateWindow(title, width, height, FLAGS)
	if device.window == nil {
		device_destroy(device)
		return false
	}

	// Below this the panels' content minimums stop fitting, whatever the layout does.
	sdl.SetWindowMinimumSize(device.window, WINDOW_MIN_W, WINDOW_MIN_H)

	device.renderer = sdl.CreateRenderer(device.window, nil)
	if device.renderer == nil {
		device_destroy(device)
		return false
	}

	// Paces the live-resize render loop; without it a drag renders unbounded.
	if !sdl.SetRenderVSync(device.renderer, 1) {
		fmt.eprintfln("failed to enable vsync: %s", sdl.GetError())
	}

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
	window_configure(device.window, toolbar_height)

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

// SDL defaults to 500ms / 32px (its own comment: "seems about right for
// touch interfaces") - too loose for a precise editor click; a slow,
// deliberate double-click or a click that drifts a few px should not
// register as one. Not a device_create param on purpose - this is a fixed
// platform behavior, not something callers get to override per instance.
@(private = "file")
DOUBLE_CLICK_TIME_MS :: 300
@(private = "file")
DOUBLE_CLICK_RADIUS_PX :: 4

@(private = "file", require_results)
sdl_init :: proc() -> bool {
	// Hints can be set anytime per SDL3 docs, but set before Init so the
	// mouse subsystem's hint callbacks pick them up on first registration
	// rather than the 500ms/32px factory default for even one frame.
	set_click_hints()

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
set_click_hints :: proc() {
	ms_buf: [8]u8
	px_buf: [8]u8
	ms := strconv.write_int(ms_buf[:], i64(DOUBLE_CLICK_TIME_MS), 10)
	px := strconv.write_int(px_buf[:], i64(DOUBLE_CLICK_RADIUS_PX), 10)

	if !sdl.SetHint(
		sdl.HINT_MOUSE_DOUBLE_CLICK_TIME,
		strings.clone_to_cstring(ms, context.temp_allocator),
	) {
		fmt.eprintln("Failed to set double-click time hint")
	}
	if !sdl.SetHint(
		sdl.HINT_MOUSE_DOUBLE_CLICK_RADIUS,
		strings.clone_to_cstring(px, context.temp_allocator),
	) {
		fmt.eprintln("Failed to set double-click radius hint")
	}
}

@(private = "file")
window_configure :: proc(window: ^sdl.Window, toolbar_height: f32) {
	if window != nil {
		// Will "jump" to center, but hidden will fix that
		sdl.SetWindowPosition(window, sdl.WINDOWPOS_CENTERED, sdl.WINDOWPOS_CENTERED)
		sdl.SetWindowMinimumSize(window, 800, 600)
		window_setup(window, toolbar_height)
		sdl.ShowWindow(window)
	}
}
