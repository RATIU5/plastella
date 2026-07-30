package editor

import clay "../../vendor/clay"
import gfx "../gfx"

toolbar_frame :: proc(frame: ^gfx.Frame) {
	if clay.UI(clay.ID("toolbar"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(32)},
			padding = {top = 10, left = 90},
		},
		backgroundColor = gfx.COLOR_GREY_850,
	},
	) {
		gfx.text("Test", .UI_BLD_13, {255, 255, 255, 255}, frame.assets)
	}
}
