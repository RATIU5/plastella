package ui

import clay "../../vendor/clay"
import render "../render"

text :: proc(
	label: string,
	ts: render.TEXT,
	color: clay.Color,
	alignment: clay.TextAlignment = .Left,
	wrap: clay.TextWrapMode = .None,
	ellipsize: f32 = 0,
) {
	render.text(label, ts, color, alignment, .None, ellipsize)
}
