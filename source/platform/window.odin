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
