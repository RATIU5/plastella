package app

import "../../vendor/clay"

Corner :: enum u8 {
	Top_Left,
	Top_Right,
	Bottom_Left,
	Bottom_Right,
}

Corners :: distinct bit_set[Corner;u8]

CORNERS_ALL :: Corners{.Top_Left, .Top_Right, .Bottom_Left, .Bottom_Right}
CORNERS_TOP :: Corners{.Top_Left, .Top_Right}
CORNERS_BOTTOM :: Corners{.Bottom_Left, .Bottom_Right}
CORNERS_LEFT :: Corners{.Top_Left, .Bottom_Left}
CORNERS_RIGHT :: Corners{.Top_Right, .Bottom_Right}

Edge :: enum u8 {
	Left,
	Right,
	Top,
	Bottom,
}

Edges :: distinct bit_set[Edge;u8]

EDGES_ALL :: Edges{.Left, .Right, .Top, .Bottom}

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

// nil keeps the style's own shape; a set squares off every corner it omits.
@(require_results)
corner_radius_mask :: proc(
	radius: clay.CornerRadius,
	corners: Maybe(Corners),
) -> clay.CornerRadius {
	kept := corners.? or_else CORNERS_ALL
	return {
		topLeft = radius.topLeft if .Top_Left in kept else 0,
		topRight = radius.topRight if .Top_Right in kept else 0,
		bottomLeft = radius.bottomLeft if .Bottom_Left in kept else 0,
		bottomRight = radius.bottomRight if .Bottom_Right in kept else 0,
	}
}

// Drop the edge a neighbour already draws, so a shared seam stays one line thick.
@(require_results)
border_width_mask :: proc(width: clay.BorderWidth, edges: Maybe(Edges)) -> clay.BorderWidth {
	kept := edges.? or_else EDGES_ALL
	return {
		left = width.left if .Left in kept else 0,
		right = width.right if .Right in kept else 0,
		top = width.top if .Top in kept else 0,
		bottom = width.bottom if .Bottom in kept else 0,
		betweenChildren = width.betweenChildren,
	}
}
