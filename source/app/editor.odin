package app

import "../../vendor/clay"

Toolbar_Tab :: enum u8 {
	Project,
	Map,
	Tileset,
	Sprites,
	Level,
	Settings,
}

Editor :: struct {
	tab:         Toolbar_Tab,
	status_text: string,
	// Borrowed from App, set once by editor_init; never nil after.
	project:     ^Project,
}

@(require_results)
editor_init :: proc(editor: ^Editor, prj: ^Project) -> bool {
	editor.project = prj
	return true
}

editor_shutdown :: proc(editor: ^Editor) {}

editor_frame :: proc(editor: ^Editor, ctx: ^Ctx) {
	assert(editor.project != nil)

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
