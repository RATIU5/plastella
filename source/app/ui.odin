package app

import "../platform"

Ui :: struct {
	focused:   string,
	tab_next:  bool,
	tab_first: string,
	tab_prev:  string,
}

Ctx :: struct {
	ui:    ^Ui,
	frame: ^Frame,
}

ui_init :: proc(_: ^Ui) -> bool {
	return true
}

ui_update :: proc(ctx: ^Ctx) {
	if platform.key_pressed(ctx.frame.input, .ESCAPE) && ctx.ui.focused != "" {
		ctx.ui.focused = ""
	}
}

ui_frame_start :: proc(ctx: ^Ctx) {
	ctx.ui.tab_first = ""
	ctx.ui.tab_prev = ""
	if ctx.ui.focused == "" && platform.key_pressed(ctx.frame.input, .TAB) {
		ctx.ui.tab_next = true
	}
}

ui_frame_end :: proc(ui: ^Ui) {
	if ui.tab_next {
		ui.focused = ui.tab_first
		ui.tab_next = false
	}
}

ui_shutdown :: proc(ui: ^Ui) {
	ui^ = {}
}

register_focusable :: proc(ctx: ^Ctx, id: string) -> bool {
	took_focus := false

	if ctx.ui.tab_next {
		ctx.ui.focused = id
		ctx.ui.tab_next = false
		took_focus = true
	}

	if ctx.ui.tab_first == "" do ctx.ui.tab_first = id

	if !took_focus && ctx.ui.focused == id && platform.key_pressed(ctx.frame.input, .TAB) {
		shift :=
			platform.key_down(ctx.frame.input, .LSHIFT) ||
			platform.key_down(ctx.frame.input, .RSHIFT)
		if shift {
			ctx.ui.focused = ctx.ui.tab_prev
			if ctx.ui.tab_prev == "" do ctx.ui.tab_next = false
		} else {
			ctx.ui.tab_next = true
		}
	}

	ctx.ui.tab_prev = id
	return took_focus
}
