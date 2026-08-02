package gfx

import "../../vendor/clay"
import "../platform"

Interaction :: struct {
	pressed_id: [platform.Mouse_Button]string,
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
	if over && platform.mouse_pressed(frame.input, button) do state.pressed_id[button] = id
	if platform.mouse_released(frame.input, button) && over && state.pressed_id[button] == id {
		state.pressed_id[button] = ""
		return true
	}
	return false
}

// Clears a press left dangling when release lands off the original id (e.g. drag off
// before release). Call once per frame after all widget code has run.
interaction_end :: proc(frame: ^Frame) {
	state := &frame.gfx.interaction
	for btn in platform.Mouse_Button {
		if platform.mouse_released(frame.input, btn) {
			state.pressed_id[btn] = ""
		}
	}
}
