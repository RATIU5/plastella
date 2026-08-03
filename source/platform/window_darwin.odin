package platform

// Reposition the native macOS traffic-light buttons (close / minimise / zoom)
// so they sit vertically centred inside a taller-than-standard custom header.
// Their horizontal positions and inter-button spacing are left to AppKit — we
// only shift Y and grow their container.
//
// Called every frame from app_update. It's idempotent — setting a frame to
// the value it already has is essentially free — and running it per-frame
// means we self-heal from any AppKit relayout (live resize, fullscreen
// transition, deminiaturise, style-mask change) without any observer /
// notification / delegate plumbing. Notification-driven attempts were tried
// and abandoned: AppKit's chrome relayout timing does not line up cleanly
// with any single public notification, and the runloop-mode / show-time
// ordering makes deferred selectors unreliable in an SDL event loop.
//
// APPROACHES CONSIDERED AND REJECTED (do not reintroduce):
//
//   1. Moving individual NSButton frames WITHOUT also growing their group
//      container (close.superview.superview). AppKit keys the shared hover-
//      glyph state to the group's geometry; a button moved out of that
//      geometry stops lighting up with its siblings on hover.
//
//   2. Moving only close.superview. AppKit re-applies its own titlebar
//      layout to that view on live resize and silently reverts the change.
//
//   3. Overriding -updateTrackingAreas on views we own to try to un-stick
//      hover. The group-hover tracking lives on AppKit-private ancestor
//      views; replacing tracking areas on views we DO own does nothing and
//      can strip legitimate tracking areas.
//
//   4. Private-API KVC into _titlebarContainerView / NSThemeFrame. Unstable
//      across macOS releases and App Store hostile.
//
// APPROACH USED (Electron / Zed pattern): grow the button cluster's grand-
// parent container (close.superview.superview) to the header height and
// top-anchor it, then set each button's Y (leaving X alone so AppKit's own
// spacing is preserved). Buttons are always fetched live via
// standardWindowButton: — never cached — because AppKit can recreate them
// across fullscreen / style-mask changes.
//
// KNOWN CAVEAT: on some macOS versions a private ancestor keeps a "ghost"
// group-hover tracking area at the original geometry that we can't remove.
// If it surfaces, drop back to a stock-height titlebar.

import NS "core:sys/darwin/Foundation"
import "base:intrinsics"
import sdl "vendor:sdl3"

// NSAutoresizingMaskOptions: NSViewWidthSizable (2) | NSViewMinYMargin (8)
// = width tracks the window, bottom margin flexes so the container stays
// pinned to the top of the window during live resize.
@(private = "file") AUTORESIZE_WIDTH_TOP :: NS.UInteger(2 | 8)

cocoa_window :: proc(window: ^sdl.Window) -> ^NS.Window {
	props := sdl.GetWindowProperties(window)
	return (^NS.Window)(sdl.GetPointerProperty(props, sdl.PROP_WINDOW_COCOA_WINDOW_POINTER, nil))
}

setup_window :: proc(window: ^sdl.Window, bar_height: f32) {
	nswindow := cocoa_window(window)
	if nswindow == nil do return
	NS.Window_setStyleMask(
		nswindow,
		{.Titled, .Closable, .Miniaturizable, .Resizable, .FullSizeContentView},
	)
	NS.Window_setTitlebarAppearsTransparent(nswindow, true)
	NS.Window_setTitleVisibility(nswindow, .Hidden)
}

reposition_traffic_lights :: proc(window: ^sdl.Window, bar_height: f32) {
	nswindow := cocoa_window(window)
	if nswindow == nil do return

	// NEVER cache these across calls — AppKit may recreate button views on
	// fullscreen / style-mask changes and any stashed pointer dangles.
	close_btn := std_window_button(nswindow, 0)
	mini_btn  := std_window_button(nswindow, 1)
	zoom_btn  := std_window_button(nswindow, 2)
	if close_btn == nil || mini_btn == nil || zoom_btn == nil do return

	parent := view_superview(close_btn)
	if parent == nil do return
	container := view_superview(parent)
	if container == nil do return

	win_frame := NS.Window_frame(nswindow)
	h := NS.Float(bar_height)

	// Grow the group container to the tall header, pinned to the top of the
	// window. Required — without this the buttons move out of the group's
	// original geometry and grouped hover breaks (see "won't work" #1 above).
	view_set_frame(container, NS.Rect{
		origin = {x = 0, y = win_frame.size.height - h},
		size   = {width = win_frame.size.width, height = h},
	})
	view_set_autoresizing_mask(container, AUTORESIZE_WIDTH_TOP)

	// Vertically centre each button. Leave X alone so AppKit's default
	// leading margin and inter-button spacing are preserved.
	btn_h := view_frame(close_btn).size.height
	origin_y := (h - btn_h) * 0.5
	for btn in ([3]^NS.View{close_btn, mini_btn, zoom_btn}) {
		f := view_frame(btn)
		view_set_frame_origin(btn, {x = f.origin.x, y = origin_y})
	}
}

// --- Objective-C selectors not already bound in core:sys/darwin/Foundation ---
// NSButton IS-A NSView, so ^NS.View is a valid receiver for all of these.

@(private = "file")
std_window_button :: proc "c" (win: ^NS.Window, which: NS.UInteger) -> ^NS.View {
	return intrinsics.objc_send(^NS.View, win, "standardWindowButton:", which)
}
@(private = "file")
view_superview :: proc "c" (v: ^NS.View) -> ^NS.View {
	return intrinsics.objc_send(^NS.View, v, "superview")
}
@(private = "file")
view_frame :: proc "c" (v: ^NS.View) -> NS.Rect {
	return intrinsics.objc_send(NS.Rect, v, "frame")
}
@(private = "file")
view_set_frame :: proc "c" (v: ^NS.View, r: NS.Rect) {
	intrinsics.objc_send(nil, v, "setFrame:", r)
}
@(private = "file")
view_set_frame_origin :: proc "c" (v: ^NS.View, p: NS.Point) {
	intrinsics.objc_send(nil, v, "setFrameOrigin:", p)
}
@(private = "file")
view_set_autoresizing_mask :: proc "c" (v: ^NS.View, mask: NS.UInteger) {
	intrinsics.objc_send(nil, v, "setAutoresizingMask:", mask)
}
