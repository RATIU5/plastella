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
STATUS_SHOW_MS :: u64(8000)

Editor :: struct {
	tab:          Toolbar_Tab,
	status_buf:   [STATUS_TEXT_MAX]u8,
	status_len:   int,
	status_ms:    u64,
	status_theme: Status_Theme,
	status_shown: bool,
	project:      ^Project,
	grid:         Grid,
}

MAIN_GAP :: f32(10)
MAIN_PAD :: f32(10)

@(require_results)
editor_init :: proc(editor: ^Editor, prj: ^Project) -> bool {
	editor.project = prj
	editor.grid = {
		gap = MAIN_GAP,
		pad = MAIN_PAD,
		count = {.X = 2, .Y = 2},
	}
	// min_px is what keeps a percentage from resolving below the width the
	// panel's own content needs on a small window.
	editor.grid.tracks[.X][0] = {
		frac     = 0.5,
		min_frac = 0.2,
		min_px   = 200,
	}
	editor.grid.tracks[.X][1] = {
		frac     = 0.5,
		min_frac = 0.2,
		min_px   = 280,
	}
	editor.grid.tracks[.Y][0] = {
		frac     = 0.6,
		min_frac = 0.2,
		min_px   = 160,
	}
	editor.grid.tracks[.Y][1] = {
		frac     = 0.4,
		min_frac = 0.15,
		min_px   = 120,
	}
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

		grid_update(ctx, &editor.grid, "main_area")

		if clay.UI(clay.ID("main_area"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				padding = {u16(MAIN_PAD), u16(MAIN_PAD), u16(MAIN_PAD), u16(MAIN_PAD)},
				// The seam elements are the gaps now.
				childGap = 0,
				layoutDirection = .TopToBottom,
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
	editor.status_shown = true
}

@(require_results)
status_text :: proc(editor: ^Editor) -> string {
	if !editor.status_shown do return ""
	return string(editor.status_buf[:editor.status_len])
}

// Returns true once when the status expires, so the idle loop can spend one frame clearing it.
@(require_results)
status_expired :: proc(editor: ^Editor) -> bool {
	if !editor.status_shown do return false
	if sdl.GetTicks() - editor.status_ms <= STATUS_SHOW_MS do return false
	editor.status_shown = false
	return true
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
