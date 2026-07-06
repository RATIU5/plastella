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

window_init :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .MSAA_4X_HINT, .WINDOW_HIGHDPI})
	rl.InitWindow(1280, 720, "Plastella")
	when ODIN_OS == .Darwin {
		setup_fullsize_titlebar()
	}
	// TODO: Center window on screen
	rl.SetWindowPosition(200, 200)
	rl.SetTargetFPS(90)
	rl.SetExitKey(nil)
}

window_shutdown :: proc() {
	rl.CloseWindow()
}

window_should_close :: proc() -> bool {
	return rl.WindowShouldClose()
}

window_minimized :: proc() -> bool {
	return rl.IsWindowMinimized() || rl.IsWindowHidden()
}

window_focused :: proc() -> bool {
	return rl.IsWindowFocused()
}

// While minimized we draw nothing, but raylib's event queue (normally pumped
// inside EndDrawing) still needs servicing or the window can never be restored.
// Wait briefly so an idle window doesn't busy-spin a core at the target FPS.
idle_pump_events :: proc() {
	rl.PollInputEvents()
	rl.WaitTime(0.05)
}
