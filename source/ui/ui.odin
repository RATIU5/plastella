package ui

import platform "../platform"

UI_Memory :: struct {
	input_states: map[string]Text_Input_State,
	focused:      string,
	tab_next:     bool,
	tab_first:    string,
	tab_prev:     string,
}

@(private)
ui_mem: ^UI_Memory

ui_init :: proc() -> ^UI_Memory {
	ui_mem = new(UI_Memory)
	return ui_mem
}

ui_update :: proc() {
	if platform.key_press(.ESCAPE) && ui_mem.focused != "" {
		ui_mem.focused = ""
	}
}

ui_frame_start :: proc() {
	ui_mem.tab_first = ""
	ui_mem.tab_prev = ""
}

ui_frame_end :: proc() {
	if ui_mem.tab_next {
		ui_mem.focused = ui_mem.tab_first
		ui_mem.tab_next = false
	}
}

// re-point the package global after a hot reload — the new dll zeroed it
ui_reload :: proc(m: ^UI_Memory) {
	ui_mem = m
}

ui_shutdown :: proc() {
	for key, s in ui_mem.input_states {
		delete(s.buf)
		delete(key)
	}
	delete(ui_mem.input_states)
	free(ui_mem)
	ui_mem = nil
}

register_focusable :: proc(id: string) -> bool {
	took_focus := false

	if ui_mem.tab_next {
		ui_mem.focused = id
		ui_mem.tab_next = false
		took_focus = true
	}

	if ui_mem.tab_first == "" do ui_mem.tab_first = id

	if !took_focus && ui_mem.focused == id && platform.key_press(.TAB) {
		shift := platform.key_down(.LEFT_SHIFT) || platform.key_down(.RIGHT_SHIFT)
		if shift {
			ui_mem.focused = ui_mem.tab_prev
			if ui_mem.tab_prev == "" do ui_mem.tab_next = false
		} else {
			ui_mem.tab_next = true
		}
	}

	ui_mem.tab_prev = id
	return took_focus
}
