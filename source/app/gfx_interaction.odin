package app

import "../../vendor/clay"
import "../platform"

// ponytail: 64 bytes per button, longer ids truncate; widen if two ids ever
// share their first 64 bytes.
PRESSED_ID_MAX :: 64

Interaction :: struct {
	pressed_id:  [platform.Mouse_Button]string,
	pressed_buf: [platform.Mouse_Button][PRESSED_ID_MAX]u8,
}

// Ids built for a frame (sub-ids, tprintf) die with the temp arena, so a press
// that outlives its frame keeps its own copy of the bytes.
press_set :: proc(state: ^Interaction, btn: platform.Mouse_Button, id: string) {
	n := copy(state.pressed_buf[btn][:], id)
	state.pressed_id[btn] = string(state.pressed_buf[btn][:n])
}

@(require_results)
pointer_over :: proc(id: string) -> bool {
	return clay.PointerOver(clay.ID(id))
}

@(require_results)
active_over :: proc(frame: ^Frame, id: string, button := platform.Mouse_Button.Left) -> bool {
	return pointer_over(id) && platform.mouse_down(frame.input, button)
}

@(require_results)
clicked :: proc(frame: ^Frame, id: string, button := platform.Mouse_Button.Left) -> bool {
	state := &frame.gfx.interaction
	over := pointer_over(id)
	if over && platform.mouse_pressed(frame.input, button) do press_set(state, button, id)
	if platform.mouse_released(frame.input, button) && over && state.pressed_id[button] == id {
		state.pressed_id[button] = ""
		return true
	}
	return false
}

// Clears a press whose release landed off the original id. Call once per
// frame, after all widget code.
interaction_end :: proc(frame: ^Frame) {
	state := &frame.gfx.interaction
	for btn in platform.Mouse_Button {
		if platform.mouse_released(frame.input, btn) {
			state.pressed_id[btn] = ""
		}
	}
}
