package editor

import "../../vendor/clay"
import "../assets"
import "../config"
import "../gfx"
import "../ui"

toolbar_frame :: proc(ctx: ^ui.Ctx) {

	if clay.UI(clay.ID("toolbar"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(config.TOOLBAR_HEIGHT)},
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
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(config.TOOLBAR_HEIGHT),
				},
				layoutDirection = .LeftToRight,
				childAlignment = {x = .Left, y = .Center},
				padding = {left = 90, right = 10, top = 10, bottom = 10},
			},
		},
		) {
			gfx.text(ctx.frame.assets, "Plastella", .UI_BLD_13, {255, 255, 255, 255})
		}

		// TOOLBAR:CENTER
		if clay.UI(clay.ID("toolbar:center"))(
		{
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(config.TOOLBAR_HEIGHT),
				},
				layoutDirection = .LeftToRight,
				childAlignment = {x = .Center, y = .Center},
				padding = {left = 10, right = 10, top = 10, bottom = 10},
			},
		},
		) {
			ui.button(ctx, "toolbar:project", assets.Ui_Icons.Project, .DEFAULT)
			ui.button(ctx, "toolbar:map", assets.Ui_Icons.Map, .DEFAULT)
			ui.button(ctx, "toolbar:tilesets", assets.Ui_Icons.Tilesets, .DEFAULT)
			ui.button(ctx, "toolbar:sprites", assets.Ui_Icons.Sprites, .DEFAULT)
			ui.button(ctx, "toolbar:level_editor", assets.Ui_Icons.Level_Editor, .DEFAULT)
			ui.button(ctx, "toolbar:settings", assets.Ui_Icons.Settings, .DEFAULT)
		}

		// TOOLBAR:RIGHT
		if clay.UI(clay.ID("toolbar:right"))(
		{
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(config.TOOLBAR_HEIGHT),
				},
				layoutDirection = .LeftToRight,
				childAlignment = {x = .Right, y = .Center},
				padding = {left = 10, right = 10, top = 10, bottom = 10},
			},
		},
		) {
			gfx.text(ctx.frame.assets, "Plastella", .UI_BLD_13, {255, 255, 255, 255})
		}
	}
}
