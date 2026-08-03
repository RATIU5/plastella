package editor

import "../../vendor/clay"
import "../ui"

Toolbar_Tab :: enum u8 {
	Project,
	Map,
	Tileset,
	Sprites,
	Level,
	Settings,
}

Editor :: struct {
	tab: Toolbar_Tab,
}

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
		toolbar_frame(ctx, editor)
	}
}
