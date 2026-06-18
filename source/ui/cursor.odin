package ui

import "core:math"
import rl "vendor:raylib"

// Text-cursor blink, shared app-wide so every widget that draws a caret looks
// the same. Color and timing are constants; the phase is per-focus (see
// cursor_visible) so the caret shows solid the instant an input is clicked.
CURSOR_COLOR :: GREY_220
CURSOR_BLINK_PERIOD :: f64(1.0) // seconds for a full on+off cycle
CURSOR_WIDTH :: f32(1)

// One pending caret per frame. Only one input holds focus app-wide, so a single
// slot is enough; whoever's focused sets it during layout, frame_end paints it
// after clay so it lands on top.
Cursor_State :: struct {
	active: bool,
	x, y:   f32, // top-left, screen pixels
	height: f32,
}

// True when the caret is in the "on" half of its blink. `elapsed` is seconds
// since the input gained focus — not absolute time — so a fresh click always
// starts solid.
cursor_visible :: proc(elapsed: f64) -> bool {
	return math.mod(elapsed, CURSOR_BLINK_PERIOD) < CURSOR_BLINK_PERIOD * 0.5
}

// Queue a caret at (x, y) `height` px tall. x is the right edge of the text, y
// its top. Only call when it should be visible; drawn after clay in frame_end.
cursor_set :: proc(x, y, height: f32) {
	state.cursor = {
		active = true,
		x      = x,
		y      = y,
		height = height,
	}
}

// Paint the pending caret (if any) and clear it. Called by frame_end after
// clay_render so the caret sits above the input's background.
cursor_flush :: proc() {
	defer state.cursor.active = false
	if !state.cursor.active do return
	c := state.cursor
	rl.DrawRectangleRec({c.x, c.y, CURSOR_WIDTH, c.height}, clay_color_to_rl_color(CURSOR_COLOR))
}
