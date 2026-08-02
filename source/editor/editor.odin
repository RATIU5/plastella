package editor

import "../../vendor/clay"
import "../ui"

Editor :: struct {}

@(require_results)
editor_init :: proc(editor: ^Editor) -> bool {
	return true
}

editor_shutdown :: proc(editor: ^Editor) {}

editor_frame :: proc(editor: ^Editor, ctx: ^ui.Ctx) {
	if clay.UI(clay.ID("editor"))(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
		},
	},
	) {
		toolbar_frame(ctx)
	}
}
