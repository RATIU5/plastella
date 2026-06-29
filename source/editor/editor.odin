package editor

Editor_State :: struct {
	sidebar_state: ^Sidebar_State,
}
editor_state: ^Editor_State

editor_init :: proc() {
	editor_state = new(Editor_State)
	editor_state.sidebar_state = sidebar_init()
}

editor_shutdown :: proc() {
	sidebar_shutdown()
	free(editor_state)
	editor_state = nil
}

editor_update :: proc() {

}
