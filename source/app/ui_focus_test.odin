package app

import "../platform"
import "core:testing"
import sdl "vendor:sdl3"

// One frame of a three-widget form, tab (optionally shifted) pressed the whole time.
@(private = "file")
tab_frame :: proc(ui: ^Ui, shift: bool, press_tab := true) {
	inp := platform.Input{}
	inp.keys_pressed[int(sdl.Scancode.TAB)] = press_tab
	inp.keys_curr[int(sdl.Scancode.TAB)] = press_tab
	inp.keys_curr[int(sdl.Scancode.LSHIFT)] = shift

	dev := platform.Device{}
	frame := Frame {
		input  = &inp,
		device = &dev,
	}
	ctx := Ctx {
		ui    = ui,
		frame = &frame,
	}

	ui_frame_start(&ctx)
	register_focusable(&ctx, "a")
	register_focusable(&ctx, "b")
	register_focusable(&ctx, "c")
	ui_frame_end(&ctx)
}

// Tab enters at the top with nothing focused, then cycles both ways and wraps.
@(test)
test_tab_cycles_both_ways :: proc(t: ^testing.T) {
	ui := Ui{}

	want := [?]string{"a", "b", "c", "a"}
	for w in want {
		tab_frame(&ui, false)
		testing.expect_value(t, ui.focused, w)
	}

	want_back := [?]string{"c", "b", "a", "c"}
	for w in want_back {
		tab_frame(&ui, true)
		testing.expect_value(t, ui.focused, w)
	}

	// Shift-tab from nothing enters at the bottom.
	ui.focused = ""
	tab_frame(&ui, true)
	testing.expect_value(t, ui.focused, "c")
}

// A widget that stops rendering loses focus.
@(test)
test_focus_dropped_when_unseen :: proc(t: ^testing.T) {
	ui := Ui{}
	tab_frame(&ui, false)
	testing.expect_value(t, ui.focused, "a")

	ui.focused = "gone"
	tab_frame(&ui, false, press_tab = false)
	testing.expect_value(t, ui.focused, "")
}
