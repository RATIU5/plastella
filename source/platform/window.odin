package platform

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
