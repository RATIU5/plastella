package platform

import "base:intrinsics"
import "core:fmt"
import NS "core:sys/darwin/Foundation"
import sdl "vendor:sdl3"

@(private = "file")
Traffic_Light :: enum NS.UInteger {
	Close       = 0,
	Miniaturize = 1,
	Zoom        = 2,
}

// Minimal binding for NSTitlebarAccessoryViewController — just enough to alloc, init,
// and set its view. The objc_class tag lets NS.new resolve the runtime class exactly
// like the vendored Window/View bindings do.
@(private = "file", objc_class = "NSTitlebarAccessoryViewController")
Titlebar_Accessory :: struct {
	using _: NS.Object,
}

cocoa_window :: proc(window: ^sdl.Window) -> ^NS.Window {
	props := sdl.GetWindowProperties(window)
	return (^NS.Window)(sdl.GetPointerProperty(props, sdl.PROP_WINDOW_COCOA_WINDOW_POINTER, nil))
}

setup_window :: proc(window: ^sdl.Window, bar_height: f32) {
	nswindow := cocoa_window(window)
	NS.Window_setStyleMask(
		nswindow,
		{.Titled, .Closable, .Miniaturizable, .Resizable, .FullSizeContentView},
	)
	NS.Window_setTitlebarAppearsTransparent(nswindow, true)
	NS.Window_setTitleVisibility(nswindow, .Hidden)

	grow_titlebar(nswindow, bar_height)
	nudge_tracking_areas(nswindow)
	reposition_traffic_lights(window, bar_height)
}

reposition_traffic_lights :: proc(window: ^sdl.Window, bar_height: f32) {
	nswindow := cocoa_window(window)

	for light in Traffic_Light {
		btn := standard_window_button(nswindow, light)
		if btn == nil do continue

		frame := view_frame(btn)
		sup := view_superview(btn)
		sup_frame := view_frame(sup)
		sup_flipped := view_is_flipped(sup)

		target_y := (bar_height - f32(frame.height)) / 2
		view_set_frame_origin(btn, {frame.x, NS.Float(target_y)})
		fmt.eprintfln(
			"[traffic] %v btn_frame=%v super_frame=%v super_flipped=%v bar_height=%f",
			light,
			frame,
			sup_frame,
			sup_flipped,
			bar_height,
		)
	}
}

/*
   Grows the real titlebar to `bar_height` via NSTitlebarAccessoryViewController — a public
   API that enlarges the window's actual chrome, rather than us just drawing taller content
   underneath it. This keeps the traffic lights in their native superview on purpose: that
   superview clips to its own bounds (hence the earlier disappearing act) and drives their
   hover glyph via an undocumented `_mouseInGroup:` call on itself (hence the lost hover
   when we reparented them into our own view). Leaving them native sidesteps both.
   */
@(private = "file")
grow_titlebar :: proc(window: ^NS.Window, bar_height: f32) {
	win_frame := NS.Window_frame(window)
	standard_mask := NS.WindowStyleMask{.Titled, .Closable, .Miniaturizable, .Resizable}
	content_rect := NS.Window_contentRectForFrameRectType(win_frame, standard_mask)
	default_h := f32(win_frame.height) - f32(content_rect.height)
	extra_h := max(bar_height - default_h, 0)
	fmt.eprintfln(
		"[titlebar] win_frame=%v content_rect=%v default_h=%f extra_h=%f",
		win_frame,
		content_rect,
		default_h,
		extra_h,
	)
	if extra_h == 0 do return

	spacer := NS.View_initWithFrame(NS.View_alloc(), {{0, 0}, {1, NS.Float(extra_h)}})
	accessory := NS.new(Titlebar_Accessory)
	intrinsics.objc_send(nil, accessory, "setView:", spacer)
	intrinsics.objc_send(nil, window, "addTitlebarAccessoryViewController:", accessory)

	after_spacer_frame := view_frame(spacer)
	fmt.eprintfln("[titlebar] spacer_frame_after_add=%v", after_spacer_frame)
}

@(private = "file")
nudge_tracking_areas :: proc(window: ^NS.Window) {
	frame := NS.Window_frame(window)
	grown := frame
	grown.height += 1
	NS.Window_setFrame(window, grown, false)
	NS.Window_setFrame(window, frame, false)
}

@(private = "file")
view_superview :: proc(view: ^NS.View) -> ^NS.View {
	return intrinsics.objc_send(^NS.View, view, "superview")
}

@(private = "file")
view_is_flipped :: proc(view: ^NS.View) -> NS.BOOL {
	return intrinsics.objc_send(NS.BOOL, view, "isFlipped")
}

@(private = "file")
standard_window_button :: proc(window: ^NS.Window, light: Traffic_Light) -> ^NS.View {
	return intrinsics.objc_send(^NS.View, window, "standardWindowButton:", light)
}

@(private = "file")
view_frame :: proc(view: ^NS.View) -> NS.Rect {
	return intrinsics.objc_send(NS.Rect, view, "frame")
}

@(private = "file")
view_set_frame_origin :: proc(view: ^NS.View, origin: NS.Point) {
	intrinsics.objc_send(nil, view, "setFrameOrigin:", origin)
}
