package app

import "../../vendor/clay"

statusbar_frame :: proc(ctx: ^Ctx, editor: ^Editor) {
	if clay.UI(clay.ID("statusbar"))(
	{
		layout = {
			sizing = {
				width = clay.SizingGrow(),
				height = clay.SizingFixed(STATUSBAR_HEIGHT),
			},
			padding = {10, 10, 5, 5},
		},
		backgroundColor = COLOR_GREY_850,
		border = {width = {top = 1}, color = COLOR_GREY_760},
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
			text(ctx.frame.assets, editor.status_text, .UI_REG_12, COLOR_GREY_340)
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
			text(ctx.frame.assets, "v" + VERSION, .UI_REG_12, COLOR_GREY_500)
		}
	}
}
