package platform

import api "../api"
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
}

WINDOW_DRAG_CAPTURE :: api.Capture(1)

// Runs after editor.update so UI interactions (e.g. a panel resize starting in
// the titlebar zone) win the click; we only drag the window if nothing else
// captured the mouse.
handle_window_drag :: proc(input: ^api.Input) {
	DRAG_ZONE :: f32(28)
	@(static) drag_offset: rl.Vector2 // transient, ok to lose on hot reload

	win_pos := rl.GetWindowPosition()

	// mouse position in screen space
	mouse_screen_abs := rl.Vector2{win_pos.x + input.mouse.x, win_pos.y + input.mouse.y}

	if input.mouse.y < DRAG_ZONE &&
	   input.left_pressed &&
	   api.capture_mouse(input, WINDOW_DRAG_CAPTURE) {
		drag_offset = {mouse_screen_abs.x - win_pos.x, mouse_screen_abs.y - win_pos.y}
	}
	if input.left_released {
		api.release_capture(input, WINDOW_DRAG_CAPTURE)
	}
	if api.has_capture(input, WINDOW_DRAG_CAPTURE) {
		rl.SetWindowPosition(
			i32(mouse_screen_abs.x - drag_offset.x),
			i32(mouse_screen_abs.y - drag_offset.y),
		)
	}
}

init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .MSAA_4X_HINT, .WINDOW_HIGHDPI})
	rl.InitWindow(1280, 720, "Plastella")
	when ODIN_OS == .Darwin {
		setup_fullsize_titlebar()
	}
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(90)
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
