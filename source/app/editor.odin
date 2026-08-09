package app

import "../../vendor/clay"
import "core:strings"
import "core:text/edit"
import "core:unicode/utf8"
import sdl "vendor:sdl3"

Toolbar_Tab :: enum u8 {
	Project,
	Assets,
	Scripts,
	Level,
}

STATUS_TEXT_MAX :: 128
STATUS_SHOW_MS :: u64(4000)

Editor :: struct {
	tab:             Toolbar_Tab,
	status_buf:      [STATUS_TEXT_MAX]u8,
	status_len:      int,
	status_ms:       u64,
	status_theme:    Status_Theme,
	// Borrowed from App, set once by editor_init; never nil after.
	project:         ^Project,
}

@(require_results)
editor_init :: proc(editor: ^Editor, prj: ^Project) -> bool {
	editor.project = prj
	return true
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

status_text_set :: proc(editor: ^Editor, text: string, theme := Status_Theme.Info) {
	editor.status_len = copy(editor.status_buf[:], text)
	editor.status_ms = sdl.GetTicks()
	editor.status_theme = theme
}

@(require_results)
status_text :: proc(editor: ^Editor) -> string {
	if sdl.GetTicks() - editor.status_ms > STATUS_SHOW_MS do return ""
	return string(editor.status_buf[:editor.status_len])
}

project_name_transform :: proc(s: ^Text_Edit, insert: string) -> string {
	lo, hi := edit.sorted_selection(&s.edit)
	text := strings.to_string(s.builder)
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
