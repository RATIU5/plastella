package platform

import api "../api"
import rl "vendor:raylib"

// Snapshot raylib input once at the top of the frame. Capture is left intact
// (it spans frames); cursor resets so this frame's handlers can re-request it.
poll_input :: proc(input: ^api.Input) {
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
