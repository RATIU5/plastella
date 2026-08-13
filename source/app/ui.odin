package app

import "../platform"
import "core:fmt"
import sdl "vendor:sdl3"

Ui :: struct {
	focused:          string,
	tab_next:         bool,
	// Backwards past the first widget: resolved to the last one at frame end.
	tab_wrap_prev:    bool,
	tab_first:        string,
	tab_prev:         string,
	// Set while the focused widget renders; reconciled in ui_frame_end.
	focus_seen:       bool,
	wants_text_input: bool,
	text_input_on:    bool,
	text_edit:        Text_Edit,
}

Ctx :: struct {
	ui:    ^Ui,
	frame: ^Frame,
}

ui_init :: proc(_: ^Ui) -> bool {
	return true
}

ui_update :: proc(ctx: ^Ctx) {
	if ctx.ui.focused == "" do return

	if platform.key_pressed(ctx.frame.input, .ESCAPE) || ctx.frame.input.focus_lost {
		ctx.ui.focused = ""
	}
}

ui_frame_start :: proc(ctx: ^Ctx) {
	ctx.ui.tab_first = ""
	ctx.ui.tab_prev = ""
	ctx.ui.focus_seen = false
	ctx.ui.wants_text_input = false
	// Nothing focused: tab enters at the top of the tree, shift-tab at the bottom.
	if ctx.ui.focused == "" && platform.key_pressed(ctx.frame.input, .TAB) {
		if tab_shift(ctx) {
			ctx.ui.tab_wrap_prev = true
		} else {
			ctx.ui.tab_next = true
		}
	}
}

@(private = "file", require_results)
tab_shift :: proc(ctx: ^Ctx) -> bool {
	return(
		platform.key_down(ctx.frame.input, .LSHIFT) ||
		platform.key_down(ctx.frame.input, .RSHIFT) \
	)
}

ui_frame_end :: proc(ctx: ^Ctx) {
	ui := ctx.ui

	// A tab wrap targets a widget that already registered (or hasn't yet), so it
	// can't have been seen; tab_prev is the last widget of the frame.
	took_tab := ui.tab_next || ui.tab_wrap_prev
	switch {
	case ui.tab_next:
		ui.focused = ui.tab_first
	case ui.tab_wrap_prev:
		ui.focused = ui.tab_prev
	case !ui.focus_seen:
		ui.focused = ""
	}
	ui.tab_next = false
	ui.tab_wrap_prev = false

	ui_sync_text_input(ui, ctx.frame.device.window, !took_tab && ui.wants_text_input)
}

ui_shutdown :: proc(ui: ^Ui, device: ^platform.Device) {
	if device != nil do ui_sync_text_input(ui, device.window, false)
	text_edit_destroy(&ui.text_edit)
	ui^ = {}
}

@(private = "file")
ui_sync_text_input :: proc(ui: ^Ui, window: ^sdl.Window, want: bool) {
	if want == ui.text_input_on do return

	ok: bool
	if want {
		props := sdl.CreateProperties()
		defer sdl.DestroyProperties(props)
		sdl.SetNumberProperty(
			props,
			sdl.PROP_TEXTINPUT_TYPE_NUMBER,
			i64(sdl.TextInputType.TEXT_NAME),
		)
		sdl.SetBooleanProperty(props, sdl.PROP_TEXTINPUT_MULTILINE_BOOLEAN, false)
		ok = sdl.StartTextInputWithProperties(window, props)
	} else {
		ok = sdl.StopTextInput(window)
	}

	if !ok {
		fmt.eprintfln("failed to %s text input: %s", "start" if want else "stop", sdl.GetError())
		return
	}
	ui.text_input_on = want
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
		if tab_shift(ctx) {
			// The previous widget already drew, so mark it seen here or frame end
			// would drop the focus it just gained.
			ctx.ui.focused = ctx.ui.tab_prev
			ctx.ui.focus_seen = ctx.ui.tab_prev != ""
			ctx.ui.tab_wrap_prev = ctx.ui.tab_prev == ""
		} else {
			ctx.ui.tab_next = true
		}
	}

	ctx.ui.tab_prev = id
	if ctx.ui.focused == id do ctx.ui.focus_seen = true
	return took_focus
}
