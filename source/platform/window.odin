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
	// Window position and cursor position, both captured at grab time, so the
	// drag is driven purely by how far the cursor has moved since — no per-frame
	// dependency on the window position.
	@(static) anchor_win: rl.Vector2 // window pos (raylib coords) at grab
	@(static) anchor_cur: rl.Vector2 // global cursor (screen points) at grab

	// Titlebar hit-test wants the window-relative cursor in points; input.mouse
	// is physical pixels under HIGHDPI.
	scale := rl.GetWindowScaleDPI()
	in_titlebar := input.mouse.y / scale.y < DRAG_ZONE

	if in_titlebar && input.left_pressed && api.capture_mouse(input, WINDOW_DRAG_CAPTURE) {
		anchor_win = rl.GetWindowPosition()
		anchor_cur = global_cursor()
	}
	if input.left_released {
		api.release_capture(input, WINDOW_DRAG_CAPTURE)
	}
	if api.has_capture(input, WINDOW_DRAG_CAPTURE) {
		// Drive the window from the OS global cursor, which is independent of the
		// window. The previous approach reconstructed the cursor as
		// GetWindowPosition() + GetMousePosition(), but GetMousePosition is
		// window-relative, so moving the window perturbed the next read — a
		// feedback loop that crept the window after the cursor stopped.
		cur := global_cursor()
		dx := cur.x - anchor_cur.x
		dy := cur.y - anchor_cur.y
		when ODIN_OS == .Darwin {
			dy = -dy // Cocoa screen-Y points up; raylib window-Y points down
		}
		rl.SetWindowPosition(i32(anchor_win.x + dx), i32(anchor_win.y + dy))
	}
}

// Absolute cursor position in screen points, independent of the window. On
// macOS this comes straight from the OS; elsewhere it is reconstructed from the
// window-relative cursor (which can creep slightly, but is adequate off-macOS).
when ODIN_OS == .Darwin {
	global_cursor :: proc() -> rl.Vector2 {
		p := NS.Event_mouseLocation()
		return {f32(p.x), f32(p.y)}
	}
} else {
	global_cursor :: proc() -> rl.Vector2 {
		wp := rl.GetWindowPosition()
		m := rl.GetMousePosition()
		s := rl.GetWindowScaleDPI()
		return {wp.x + m.x / s.x, wp.y + m.y / s.y}
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

// True when nothing is on screen, so the frame's layout + draw can be skipped.
window_minimized :: proc() -> bool {
	return rl.IsWindowMinimized() || rl.IsWindowHidden()
}

// While minimized we draw nothing, but raylib's event queue (normally pumped
// inside EndDrawing) still needs servicing or the window can never be restored.
// Wait briefly so an idle window doesn't busy-spin a core at the target FPS.
idle_pump_events :: proc() {
	rl.PollInputEvents()
	rl.WaitTime(0.05) // ~20Hz: cheap, still restores promptly
}

is_force_reload_pressed :: proc() -> bool {
	return rl.IsKeyPressed(.F5)
}

is_force_restart_pressed :: proc() -> bool {
	return rl.IsKeyPressed(.F6)
}
