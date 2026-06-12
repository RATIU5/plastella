package editor

import api "../api"
import ui "../ui"

// Panel convention and hot-reload state rules: see docs/architecture.md.

// One field per panel; each panel defines its own state struct in its file.
Editor_State :: struct {
	sidebar: Sidebar_State,
}

editor_ctx: ^Editor_State

init :: proc() -> ^Editor_State {
	editor_ctx = new(Editor_State)
	editor_ctx^ = {
		sidebar = {width = 250},
	}
	return editor_ctx
}


frame :: proc(input: ^api.Input) {
	ui.frame_begin(input.mouse, input.left_down)

	sidebar(input)

	ui.frame_end()
}

reload :: proc(ctx: rawptr) {
	editor_ctx = (^Editor_State)(ctx)
}

shutdown :: proc() {
	free(editor_ctx)
	editor_ctx = nil
}
