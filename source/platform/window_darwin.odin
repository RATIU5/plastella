package platform

// Reposition the native macOS traffic-light buttons (close / minimise / zoom)
// so they sit vertically centred inside a taller-than-standard custom header.
//
// APPROACHES REJECTED — do not reintroduce:
//   1. Moving individual NSButton frames without also growing their group
//      container (close.superview.superview). AppKit keys grouped-hover
//      glyph state to the group's geometry; a button moved out of it stops
//      lighting up with its siblings.
//   2. Moving only close.superview. AppKit reapplies its own titlebar layout
//      to that view on live resize and reverts the change.
//   3. Overriding -updateTrackingAreas on views we own. Group-hover tracking
//      lives on AppKit-private ancestor views; replacing tracking areas on
//      views we own does nothing and can strip legitimate ones.
//   4. Private-API KVC into _titlebarContainerView / NSThemeFrame. Unstable
//      across macOS releases and App Store hostile.
//
// APPROACH: grow close.superview.superview to the header height and top-
// anchor it via NSAutoresizingMask, then set each button's Y (leaving X to
// AppKit so default leading margin and inter-button spacing are preserved).
// Buttons are always fetched live via standardWindowButton: — never cached —
// because AppKit can recreate them across fullscreen / style-mask changes.

import "base:intrinsics"
import "base:runtime"
import NS "core:sys/darwin/Foundation"
import sdl "vendor:sdl3"

Window_Button :: enum NS.UInteger {
	Close       = 0,
	Miniaturize = 1,
	Zoom        = 2,
}

// NSAutoresizingMaskOptions: NSViewWidthSizable (2) | NSViewMinYMargin (8).
// Container tracks window width and stays pinned to the top on live resize.
@(private = "file")
CONTAINER_AUTORESIZE :: NS.UInteger(2 | 8)

Render_Callback :: #type proc "c" ()

// File-scoped singleton justified: one window per process, and SDL's event
// watch userdata is an untyped rawptr that cannot carry inline state cheaply.
@(private = "file")
Watch :: struct {
	window:     ^sdl.Window,
	bar_height: f32,
	installed:  bool,
	// Reentrancy is guarded by the callback itself, not here.
	render:     Render_Callback,
}
@(private = "file")
watch: Watch

/*
Returns the underlying NSWindow backing an SDL window on macOS.

Inputs:
- window: A live SDL_Window.

Returns:
- The NSWindow, or nil if SDL did not populate the Cocoa property.
*/
@(require_results)
cocoa_window :: proc(window: ^sdl.Window) -> ^NS.Window {
	assert(window != nil)
	props := sdl.GetWindowProperties(window)
	return (^NS.Window)(sdl.GetPointerProperty(props, sdl.PROP_WINDOW_COCOA_WINDOW_POINTER, nil))
}

/*
Configures the window to draw content edge-to-edge behind a transparent
titlebar and installs the resize event watch. Call once at window creation,
before ShowWindow. Pair with window_teardown.

Inputs:
- window: A live SDL_Window.
- bar_height: Height in points of the custom header the buttons will be
  centred inside.
*/
window_setup :: proc(window: ^sdl.Window, bar_height: f32) {
	assert(window != nil)
	assert(bar_height > 0)

	nswindow := cocoa_window(window)
	if nswindow == nil do return

	NS.Window_setStyleMask(
		nswindow,
		{.Titled, .Closable, .Miniaturizable, .Resizable, .FullSizeContentView},
	)
	NS.Window_setTitlebarAppearsTransparent(nswindow, true)
	NS.Window_setTitleVisibility(nswindow, .Hidden)

	watch.window = window
	watch.bar_height = bar_height
	if !watch.installed {
		// Ignored: failure only degrades live resize; the per-frame call from
		// app_update still repositions on every non-resize frame.
		_ = sdl.AddEventWatch(resize_watch, nil)
		watch.installed = true
	}
}

/*
Removes the resize event watch installed by window_setup. Idempotent and
nil-safe so it is fine to call from partial-construction cleanup paths.
*/
window_teardown :: proc() {
	if watch.installed {
		sdl.RemoveEventWatch(resize_watch, nil)
	}
	watch = {}
}

/*
Registers the render callback the resize watch drives during macOS live resize.
Must be re-registered after every hot reload (Appendix A rule 6): SDL keeps the
watch proc pointer, and the callback's address changes when the module swaps.

Inputs:
- cb: The render callback, or nil to disable.
*/
window_set_render_callback :: proc(cb: Render_Callback) {
	watch.render = cb
}

/*
Repositions the traffic lights inside the custom header. Idempotent — setting
a frame to its current value is free — and safe to call every frame from
app_update. It is also called from the resize event watch during macOS live
resize, when the SDL event loop is blocked in NSEventTrackingRunLoopMode and
per-frame ticks stop firing.

Inputs:
- window: A live SDL_Window.
- bar_height: Header height in points.
*/
reposition_traffic_lights :: proc(window: ^sdl.Window, bar_height: f32) {
	assert(window != nil)
	assert(bar_height > 0)

	nswindow := cocoa_window(window)
	if nswindow == nil do return

	// NEVER cache these across calls: AppKit may recreate button views on
	// fullscreen / style-mask changes and any stashed pointer dangles. All
	// nil-returns below are transient AppKit states (window not yet titled,
	// buttons being rebuilt), not programmer errors.
	close_button := standard_window_button(nswindow, .Close)
	miniaturize_button := standard_window_button(nswindow, .Miniaturize)
	zoom_button := standard_window_button(nswindow, .Zoom)
	if close_button == nil || miniaturize_button == nil || zoom_button == nil do return

	parent := view_superview(close_button)
	if parent == nil do return
	container := view_superview(parent)
	if container == nil do return

	window_frame := NS.Window_frame(nswindow)
	h := NS.Float(bar_height)

	// Grow the group container to the tall header, pinned to the top of the
	// window. Without this the buttons drift outside the group's tracking
	// geometry and grouped hover breaks (rejected approach #1 in file header).
	view_set_frame(
		container,
		NS.Rect {
			origin = {x = 0, y = window_frame.size.height - h},
			size = {width = window_frame.size.width, height = h},
		},
	)
	view_set_autoresizing_mask(container, CONTAINER_AUTORESIZE)

	// Vertically center each button. Leave X alone so AppKit's default
	// leading margin and inter-button spacing are preserved.
	button_height := view_frame(close_button).size.height
	origin_y := (h - button_height) * 0.5
	buttons := [?]^NS.View{close_button, miniaturize_button, zoom_button}
	for button in buttons {
		frame := view_frame(button)
		view_set_frame_origin(button, {x = frame.origin.x, y = origin_y})
	}
}

// Fires on AppKit's main-thread dispatch even while WaitEventTimeout is parked
// in NSEventTrackingRunLoopMode. Render is driven off PIXEL_SIZE_CHANGED only:
// it fires after Metal resizes the drawable, so GetCurrentRenderOutputSize
// returns the fresh size. RESIZED fires first with a stale drawable, so
// rendering on it produces a visible axis smash on fast drags.
@(private = "file")
resize_watch :: proc "c" (_userdata: rawptr, event: ^sdl.Event) -> bool {
	if watch.window == nil do return true
	context = runtime.default_context()

	#partial switch event.type {
	case .WINDOW_RESIZED:
		reposition_traffic_lights(watch.window, watch.bar_height)
	case .WINDOW_PIXEL_SIZE_CHANGED:
		reposition_traffic_lights(watch.window, watch.bar_height)

		if watch.render == nil do return true
		watch.render()
	}
	return true
}

@(private = "file", require_results)
standard_window_button :: proc "c" (window: ^NS.Window, which: Window_Button) -> ^NS.View {
	return intrinsics.objc_send(^NS.View, window, "standardWindowButton:", which)
}
@(private = "file", require_results)
view_superview :: proc "c" (view: ^NS.View) -> ^NS.View {
	return intrinsics.objc_send(^NS.View, view, "superview")
}
@(private = "file", require_results)
view_frame :: proc "c" (view: ^NS.View) -> NS.Rect {
	return intrinsics.objc_send(NS.Rect, view, "frame")
}
@(private = "file")
view_set_frame :: proc "c" (view: ^NS.View, rect: NS.Rect) {
	intrinsics.objc_send(nil, view, "setFrame:", rect)
}
@(private = "file")
view_set_frame_origin :: proc "c" (view: ^NS.View, point: NS.Point) {
	intrinsics.objc_send(nil, view, "setFrameOrigin:", point)
}
@(private = "file")
view_set_autoresizing_mask :: proc "c" (view: ^NS.View, mask: NS.UInteger) {
	intrinsics.objc_send(nil, view, "setAutoresizingMask:", mask)
}
