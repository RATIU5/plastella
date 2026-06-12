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


update :: proc(input: ^api.Input) {
	sidebar_update(input)
}

// The frame loop: open a UI frame, declare each panel, then present. As panels
// multiply this stays the single place that lists what gets drawn, in order.
draw :: proc() {
	ui.frame_begin()

	sidebar_draw()

	ui.frame_end()
}

reload :: proc(ctx: rawptr) {
	editor_ctx = (^Editor_State)(ctx)
}

shutdown :: proc() {
	free(editor_ctx)
	editor_ctx = nil
}
