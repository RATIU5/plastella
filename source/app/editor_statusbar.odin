package app

import "../../vendor/clay"

Status_Theme :: enum u8 {
	Info,
	Warning,
	Error,
}

@(rodata)
status_colors := [Status_Theme]clay.Color {
	.Info    = COLOR_GREY_340,
	.Warning = COLOR_WARNING,
	.Error   = COLOR_ERROR_150,
}

statusbar_frame :: proc(ctx: ^Ctx, editor: ^Editor) {
	if clay.UI(clay.ID("statusbar"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(STATUSBAR_HEIGHT)},
		},
		backgroundColor = COLOR_GREY_850,
		border = {width = {top = 1}, color = COLOR_GREY_760},
	},
	) {
		if clay.UI(clay.ID("statusbar:left"))(
		{
			layout = {
				sizing = {
					width = clay.SizingPercent(1.0 / 3.0),
					height = clay.SizingFixed(STATUSBAR_HEIGHT),
				},
				layoutDirection = .LeftToRight,
				childAlignment = {x = .Left, y = .Center},
				padding = {10, 10, 0, 0},
			},
		},
		) {

		}

		if clay.UI(clay.ID("statusbar:center"))(
		{
			layout = {
				sizing = {
					width = clay.SizingPercent(1.0 / 3.0),
					height = clay.SizingFixed(STATUSBAR_HEIGHT),
				},
				layoutDirection = .LeftToRight,
				childAlignment = {x = .Center, y = .Center},
				padding = {left = 10, right = 10, top = 10, bottom = 10},
			},
		},
		) {
			status_text := status_text(editor)
			if status_text != "" &&
			   button(ctx, "statusbar:button_error", status_text, {theme = .Status_Error}) {
			}
		}

		if clay.UI(clay.ID("statusbar:right"))(
		{
			layout = {
				sizing = {
					width = clay.SizingPercent(1.0 / 3.0),
					height = clay.SizingFixed(STATUSBAR_HEIGHT),
				},
				layoutDirection = .LeftToRight,
				childAlignment = {x = .Right, y = .Center},
				padding = {left = 10, right = 10, top = 10, bottom = 10},
			},
		},
		) {
			text(ctx.frame.assets, "v" + VERSION, .UI_REG_12, COLOR_GREY_500)
		}
	}
}
