package ui

import clay "../../vendor/clay"

Border_Direction :: enum u8 {
	HORIZONTAL,
	VERTICAL,
}

border :: proc(
	id: string,
	color: clay.Color = COLOR_SEPARATOR,
	width: f32 = 1,
	direction: Border_Direction = .HORIZONTAL,
	margin: u16 = 5,
) {
	// outer: transparent, owns the outside space via padding
	outer_sizing := clay.Sizing {
		width  = direction == .VERTICAL ? clay.SizingFit() : clay.SizingGrow(),
		height = direction == .HORIZONTAL ? clay.SizingFit() : clay.SizingGrow(),
	}
	padding := clay.Padding {
		left   = direction == .VERTICAL ? margin : 0,
		right  = direction == .VERTICAL ? margin : 0,
		top    = direction == .HORIZONTAL ? margin : 0,
		bottom = direction == .HORIZONTAL ? margin : 0,
	}
	// inner: the actual colored line, grows to fill remaining space
	line_sizing := clay.Sizing {
		width  = direction == .VERTICAL ? clay.SizingFixed(width) : clay.SizingGrow(),
		height = direction == .HORIZONTAL ? clay.SizingFixed(width) : clay.SizingGrow(),
	}

	if clay.UI(clay.ID(id))({layout = {sizing = outer_sizing, padding = padding}}) {
		if clay.UI(clay.ID(id, 1))({layout = {sizing = line_sizing}, backgroundColor = color}) {}
	}
}
