package ui

import clay "../../vendor/clay"
import render "../render"

Input_Style :: struct {
	font:         render.TEXT,
	padding:      clay.Padding,
	border_width: clay.BorderWidth,
	border_color: [Color_State]clay.Color,
	bg_color:     [Color_State]clay.Color,
	fg_color:     [Color_State]clay.Color,
	ph_color:     clay.Color,
	radius:       clay.CornerRadius,
}

INPUT :: enum u8 {
	DEFAULT,
}

input_styles := [INPUT]Input_Style {
	.DEFAULT = {},
}

@(private = "file")
input_text :: proc(
	id: string,
	value: string,
	placeholder: string,
	theme: INPUT,
	disabled := false,
) {

}
