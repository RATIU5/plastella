package app

import "../../vendor/clay"

Sizing_Auto :: enum u8 {
	Grow,
	Fit,
}

Sizing :: union {
	Sizing_Auto,
	f32,
}

sizing_to_clay :: proc(width: Sizing) -> clay.Sizing {
	new_width: clay.SizingAxis

	switch type in width {
	case Sizing_Auto:
		switch type {
		case .Grow:
			new_width = clay.SizingGrow()
		case .Fit:
			new_width = clay.SizingFit()
		}
	case f32:
		new_width = clay.SizingFixed(type)
	}

	return {width = new_width, height = clay.SizingFit()}
}
