package app

import "../../vendor/clay"
import "core:strings"
import "core:text/edit"
import "core:unicode/utf8"

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
	editor.proj_name_input.transform = project_name_transform
	editor.proj_name_input.validate = project_name_validate
	text_input_set(&editor.proj_name_input, project_name(prj))
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

status_text_set :: proc(editor: ^Editor, text: string) {
	editor.status_text = strings.clone(text, context.temp_allocator)
}

project_name_transform :: proc(s: ^Text_Input_State, insert: string) -> string {
	lo, hi := edit.sorted_selection(&s.edit)
	text := text_input_get(s)
	kept := utf8.rune_count_in_string(text) - utf8.rune_count_in_string(text[lo:hi])
	room := PROJECT_NAME_MAX_RUNES - kept
	if room <= 0 do return ""

	b := strings.builder_make(0, len(insert), context.temp_allocator)
	written := 0
	for r in insert {
		if written >= room do break
		strings.write_rune(&b, r)
		written += 1
	}
	return strings.to_string(b)
}

project_name_validate :: proc(
	user_data: rawptr,
	s: ^Text_Input_State,
) -> (
	Input_Validity,
	string,
) {
	if len(strings.trim_space(text_input_get(s))) == 0 do return .Error, "Cannot be empty"
	if text_input_rejected(s) do return .Warning, "Max 25 characters reached"
	return .None, ""
}
