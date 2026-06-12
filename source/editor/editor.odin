package editor

import ui "../ui"

// Panel convention and hot-reload state rules: see docs/architecture.md.

Editor_State :: struct {
	sidebar_width:    f32,
	sidebar_resizing: bool,
}

editor_ctx: ^Editor_State

init :: proc() -> ^Editor_State {
	editor_ctx = new(Editor_State)
	editor_ctx^ = {
		sidebar_width    = 250,
		sidebar_resizing = false,
	}
	return editor_ctx
}


update :: proc() {
	sidebar_update()
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
