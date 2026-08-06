package app

import "../../vendor/clay"

Toolbar_Tab :: enum u8 {
	Project,
	Assets,
	Scripts,
	Level,
}

Editor :: struct {
	tab:             Toolbar_Tab,
	status_text:     string,
	// Borrowed from App, set once by editor_init; never nil after.
	project:         ^Project,
	proj_name_input: Text_Input_State,
}

@(require_results)
editor_init :: proc(editor: ^Editor, prj: ^Project) -> bool {
	editor.project = prj
	text_input_init(&editor.proj_name_input)
	text_input_set(&editor.proj_name_input, prj.name)
	return true
}

editor_shutdown :: proc(editor: ^Editor) {
	text_input_destroy(&editor.proj_name_input)
}

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

		if clay.UI(clay.ID("main_area"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				padding = {10, 10, 10, 10},
				childGap = 10,
			},
		},
		) {
			project_view(ctx, editor)
		}

		statusbar_frame(ctx, editor)
	}
}
