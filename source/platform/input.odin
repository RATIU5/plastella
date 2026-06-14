package platform

import api "../api"
import rl "vendor:raylib"

// Snapshot raylib input once at the top of the frame. Capture is left intact
// (it spans frames); cursor resets so this frame's handlers can re-request it.
poll_input :: proc(input: ^api.Input) {
	// Unfocused: the OS still reports a cursor over our region, but no click
	// here is meant for us. Suppress button input and park the mouse off-window
	// so nothing hovers, and cancel any in-flight drag/press — a capture whose
	// mouse-up landed in another app would otherwise stick forever. This is the
	// one sanctioned place to reset `capture`, which we never touch otherwise.
	if !rl.IsWindowFocused() {
		input.left_pressed = false
		input.left_released = false
		input.left_down = false
		input.mouse = {-1, -1}
		input.capture = api.CAPTURE_NONE
		input.cursor = .Default
		return
	}

	m := rl.GetMousePosition()
	input.mouse = {m.x, m.y}
	input.left_pressed = rl.IsMouseButtonPressed(.LEFT)
	input.left_released = rl.IsMouseButtonReleased(.LEFT)
	input.left_down = rl.IsMouseButtonDown(.LEFT)
	input.cursor = .Default
}

// Apply whatever cursor this frame's input handlers requested.
apply_cursor :: proc(input: ^api.Input) {
	switch input.cursor {
	case .Default:
		rl.SetMouseCursor(.DEFAULT)
	case .Resize_EW:
		rl.SetMouseCursor(.RESIZE_EW)
	case .Pointer:
		rl.SetMouseCursor(.POINTING_HAND)
	}
}
