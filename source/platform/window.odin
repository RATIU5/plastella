package platform

import "base:intrinsics"
import "core:c/libc"
import CF "core:sys/darwin/CoreFoundation"
import NS "core:sys/darwin/Foundation"
import rl "vendor:raylib"

when ODIN_OS == .Darwin {
	setup_fullsize_titlebar :: proc() {
		nswindow := (^NS.Window)(rl.GetWindowHandle())
		NS.Window_setStyleMask(
			nswindow,
			{.Titled, .Closable, .Miniaturizable, .Resizable, .FullSizeContentView},
		)
		NS.Window_setTitlebarAppearsTransparent(nswindow, true)
		NS.Window_setTitleVisibility(nswindow, .Hidden)
		NS.Window_setMovableByWindowBackground(nswindow, true)
	}

	CFRunLoopRef :: distinct rawptr
	CFRunLoopObserverRef :: distinct rawptr
	CFAllocatorRef :: distinct rawptr

	CFRunLoopActivity_BeforeWaiting :: CF.OptionFlags(1 << 5)
	CFRunLoopActivity_AfterWaiting :: CF.OptionFlags(1 << 6)

	CFRunLoopObserverCallBack :: #type proc "c" (
		observer: CFRunLoopObserverRef,
		activity: CF.OptionFlags,
		info: rawptr,
	)

	foreign import CF_lib "system:CoreFoundation.framework"
	@(default_calling_convention = "c")
	foreign CF_lib {
		kCFRunLoopCommonModes: CF.String
		CFRunLoopGetCurrent :: proc() -> CFRunLoopRef ---

		CFRunLoopObserverCreate :: proc(allocator: CFAllocatorRef, activities: CF.OptionFlags, repeats: b8, order: CF.Index, callout: CFRunLoopObserverCallBack, ctx: rawptr) -> CFRunLoopObserverRef ---

		CFRunLoopAddObserver :: proc(rl_loop: CFRunLoopRef, observer: CFRunLoopObserverRef, mode: CF.String) ---
	}

	window_in_live_resize :: proc "contextless" () -> bool {
		handle := rl.GetWindowHandle()
		if handle == nil {
			return false
		}
		nswindow := (^NS.Window)(handle)
		return intrinsics.objc_send(bool, nswindow, "inLiveResize")
	}

	@(private)
	resize_render_cb: proc "c" () = nil

	set_resize_render_callback :: proc(cb: proc "c" ()) {
		resize_render_cb = cb
	}

	@(private)
	run_loop_observer_cb :: proc "c" (
		observer: CFRunLoopObserverRef,
		activity: CF.OptionFlags,
		info: rawptr,
	) {
		libc.printf("observer fired, inLiveResize=%d\n", i32(window_in_live_resize()))
		if resize_render_cb != nil && window_in_live_resize() {
			resize_render_cb()
		}
	}

	setup_live_resize_rendering :: proc() {
		observer := CFRunLoopObserverCreate(
			nil,
			CFRunLoopActivity_BeforeWaiting | CFRunLoopActivity_AfterWaiting,
			true,
			0,
			run_loop_observer_cb,
			nil,
		)
		loop := CFRunLoopGetCurrent()
		CFRunLoopAddObserver(loop, observer, kCFRunLoopCommonModes)

		tracking_mode := CF.StringMakeConstantString("NSEventTrackingRunLoopMode")
		CFRunLoopAddObserver(CFRunLoopGetCurrent(), observer, tracking_mode)
	}
}

handle_window_drag :: proc() {
	DRAG_ZONE :: f32(28)
	@(static) dragging := false
	@(static) drag_offset: rl.Vector2

	mouse_screen := rl.GetMousePosition()
	win_pos := rl.GetWindowPosition()

	// mouse position in screen space
	mouse_screen_abs := rl.Vector2{win_pos.x + mouse_screen.x, win_pos.y + mouse_screen.y}

	if mouse_screen.y < DRAG_ZONE && rl.IsMouseButtonPressed(.LEFT) {
		dragging = true
		drag_offset = {mouse_screen_abs.x - win_pos.x, mouse_screen_abs.y - win_pos.y}
	}
	if rl.IsMouseButtonReleased(.LEFT) {
		dragging = false
	}
	if dragging {
		rl.SetWindowPosition(
			i32(mouse_screen_abs.x - drag_offset.x),
			i32(mouse_screen_abs.y - drag_offset.y),
		)
	}
}

init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Plastella")
	when ODIN_OS == .Darwin {
		setup_fullsize_titlebar()
	}
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(200)
	rl.SetExitKey(nil)
}

shutdown_window :: proc() {
	rl.CloseWindow()
}

window_should_close :: proc() -> bool {
	return rl.WindowShouldClose()
}

is_force_reload_pressed :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

is_force_restart_pressed :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}
