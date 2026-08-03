package editor

import "../../vendor/clay"
import "../config"
import "../gfx"
import "../ui"
import "./editor_types"

statusbar_frame :: proc(ctx: ^ui.Ctx, editor: ^editor_types.Editor) {
	if clay.UI(clay.ID("statusbar"))(
	{
		layout = {
			sizing = {
				width = clay.SizingGrow(),
				height = clay.SizingFixed(config.STATUSBAR_HEIGHT),
			},
			padding = {10, 10, 5, 5},
		},
		backgroundColor = gfx.COLOR_GREY_850,
		border = {width = {top = 1}, color = gfx.COLOR_GREY_760},
	},
	) {
		// STATUSBAR:LEFT
		if clay.UI(clay.ID("statusbar:left"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = .LeftToRight,
				childAlignment = {x = .Left, y = .Center},
			},
		},
		) {
			ui.text(ctx.frame.assets, editor.status_text, .UI_REG_12, gfx.COLOR_GREY_340)
		}

		// STATUSBAR:RIGHT
		if clay.UI(clay.ID("statusbar:right"))(
		{
			layout = {
				sizing = {width = clay.SizingFit(), height = clay.SizingGrow()},
				layoutDirection = .LeftToRight,
				childAlignment = {x = .Right, y = .Center},
			},
		},
		) {
			ui.text(ctx.frame.assets, "v" + config.VERSION, .UI_REG_12, gfx.COLOR_GREY_500)
		}
	}
}
