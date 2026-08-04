package ui

import clay "../../vendor/clay"

Sizing_Auto :: enum u8 {
	Grow,
	Fit,
}

Sizing :: union {
	Sizing_Auto,
	f32,
}

sizing_to_clay :: proc(width: Sizing, height: Sizing = .Fit) -> clay.Sizing {
	new_width: clay.SizingAxis
	new_height: clay.SizingAxis

	switch type in width {
	case Sizing_Auto:
		if type == .Grow {
			new_width = clay.SizingGrow()
		} else if type == .Fit {
			new_width = clay.SizingFit()
		} else {
			new_width = clay.SizingFit()
		}
	case f32:
		new_width = clay.SizingFixed(type)
	}

	switch type in height {
	case Sizing_Auto:
		if type == .Grow {
			new_height = clay.SizingGrow()
		} else if type == .Fit {
			new_height = clay.SizingFit()
		} else {
			new_height = clay.SizingFit()
		}
	case f32:
		new_height = clay.SizingFixed(type)
	}

	return {width = new_width, height = new_height}
}
