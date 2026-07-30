package editor

import clay "../../vendor/clay"
import gfx "../gfx"

toolbar_frame :: proc(frame: ^gfx.Frame) {
	TOOLBAR_HEIGHT: f32 : 32
	if clay.UI(clay.ID("toolbar"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(TOOLBAR_HEIGHT)},
			// padding = {top = 10, left = 90},
		},
		backgroundColor = gfx.COLOR_GREY_850,
		border = {width = {bottom = 1}, color = gfx.COLOR_GREY_760},
	},
	) {
		// TOOLBAR:LEFT
		if clay.UI(clay.ID("toolbar:left"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(TOOLBAR_HEIGHT)},
				layoutDirection = .LeftToRight,
				childAlignment = {x = .Left, y = .Center},
				padding = {left = 90, right = 10, top = 10, bottom = 10},
			},
		},
		) {
			gfx.text("Plastella", .UI_BLD_13, {255, 255, 255, 255}, frame.assets)
		}

		// TOOLBAR:CENTER
		if clay.UI(clay.ID("toolbar:center"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(TOOLBAR_HEIGHT)},
				layoutDirection = .LeftToRight,
				childAlignment = {x = .Center, y = .Center},
				padding = {left = 10, right = 10, top = 10, bottom = 10},
			},
		},
		) {
			gfx.text("Plastella", .UI_BLD_13, {255, 255, 255, 255}, frame.assets)
		}

		// TOOLBAR:RIGHT
		if clay.UI(clay.ID("toolbar:right"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(TOOLBAR_HEIGHT)},
				layoutDirection = .LeftToRight,
				childAlignment = {x = .Right, y = .Center},
				padding = {left = 10, right = 10, top = 10, bottom = 10},
			},
		},
		) {
			gfx.text("Plastella", .UI_BLD_13, {255, 255, 255, 255}, frame.assets)
		}
	}
}
