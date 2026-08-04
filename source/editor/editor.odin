package editor

import "../../vendor/clay"
import "../project"
import "../ui"
import "./editor_types"

@(require_results)
editor_init :: proc(editor: ^editor_types.Editor, prj: ^project.Project) -> bool {
	editor.project = prj
	return true
}

editor_shutdown :: proc(editor: ^editor_types.Editor) {}

editor_frame :: proc(editor: ^editor_types.Editor, ctx: ^ui.Ctx) {
	if clay.UI(clay.ID("editor"))(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
		},
	},
	) {
		toolbar_frame(ctx, editor)
		main_editor_frame(ctx, editor)
		statusbar_frame(ctx, editor)
	}
}
