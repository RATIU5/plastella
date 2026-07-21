package ui

UI_Memory :: struct {
	input_states:  map[string]Text_Input_State,
	focused_input: string,
}

@(private)
ui_mem: ^UI_Memory

ui_init :: proc() -> ^UI_Memory {
	ui_mem = new(UI_Memory)
	return ui_mem
}

// re-point the package global after a hot reload — the new dll zeroed it
ui_reload :: proc(m: ^UI_Memory) {
	ui_mem = m
}
