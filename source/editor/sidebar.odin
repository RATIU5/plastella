package editor

SIDEBAR_WIDTH_DEFAULT: f32 : 250

Sidebar_State :: struct {
	width: f32,
}
sidebar_state: ^Sidebar_State

sidebar_init :: proc() -> ^Sidebar_State {
	sidebar_state = new(Sidebar_State)
	sidebar_state.width = SIDEBAR_WIDTH_DEFAULT

	return sidebar_state
}

sidebar_shutdown :: proc() {
	free(sidebar_state)
	sidebar_state = nil
}

sidebar_update :: proc() {

}
