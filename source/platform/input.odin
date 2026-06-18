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
	input.char_count = 0
	input.backspace = false
	input.backspace_all = false
	input.backspace_word = false
	input.delete_forward = false
	input.escape = false

	if !rl.IsWindowFocused() {
		input.left_pressed = false
		input.left_released = false
		input.left_down = false
		input.mouse = {-1, -1}
		input.capture = api.CAPTURE_NONE
		input.cursor = .Default
		return
	}

	// Drain raylib's char queue: only printable codepoints land here, so ESC,
	// arrows, etc. are filtered for free. Cap at the buffer; overflow this
	// frame is unreachable in practice (queue is keystrokes since last poll).
	for input.char_count < len(input.chars) {
		c := rl.GetCharPressed()
		if c == 0 do break
		input.chars[input.char_count] = c
		input.char_count += 1
	}
	// IsKeyPressedRepeat covers held-down backspace auto-repeat.
	input.backspace = rl.IsKeyPressed(.BACKSPACE) || rl.IsKeyPressedRepeat(.BACKSPACE)
	if input.backspace {
		input.backspace_all = rl.IsKeyDown(.LEFT_SUPER) || rl.IsKeyDown(.RIGHT_SUPER)
		input.backspace_word = rl.IsKeyDown(.LEFT_CONTROL) || rl.IsKeyDown(.RIGHT_CONTROL)
	}
	input.delete_forward = rl.IsKeyPressed(.DELETE) || rl.IsKeyPressedRepeat(.DELETE)
	input.escape = rl.IsKeyPressed(.ESCAPE)

	input.time = rl.GetTime()
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
	case .Text:
		rl.SetMouseCursor(.IBEAM)
	case .Not_Allowed:
		rl.SetMouseCursor(.NOT_ALLOWED)
	}
}
