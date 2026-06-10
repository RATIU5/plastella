package platform

import rl "vendor:raylib"

init_window :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT})
	rl.InitWindow(1280, 720, "Plastella")
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
