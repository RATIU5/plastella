package render

import platform "../platform"

@(private)
pressed_id: [platform.Mouse_Button]string

active_over :: proc(label: string, button := platform.Mouse_Button.LEFT) -> bool {
	return pointer_over(label) && platform.mouse_down(button)
}

clicked :: proc(label: string, button := platform.Mouse_Button.LEFT) -> bool {
	over := pointer_over(label)
	if over && platform.mouse_press(button) do pressed_id[button] = label
	if platform.mouse_release(button) && over && pressed_id[button] == label {
		pressed_id[button] = ""
		return true
	}
	return false
}

interaction_end :: proc() {
	for btn in platform.Mouse_Button {
		if platform.mouse_release(btn) {
			pressed_id[btn] = ""
		}
	}
}
