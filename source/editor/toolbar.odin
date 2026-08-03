package editor

import "../../vendor/clay"
import "../config"
import "../gfx"
import "../ui"

toolbar_tabs := [Toolbar_Tab]ui.Tab {
	.Project = {id = "toolbar:tab:project", label = "Project"},
	.Map = {id = "toolbar:tab:map", label = "Map", disabled = true},
	.Tileset = {id = "toolbar:tab:tileset", label = "Tileset", disabled = true},
	.Sprites = {id = "toolbar:tab:sprites", label = "Sprites", disabled = true},
	.Level = {id = "toolbar:tab:level", label = "Level", disabled = true},
	.Settings = {id = "toolbar:tab:settings", label = "Settings", disabled = true},
}

toolbar_frame :: proc(ctx: ^ui.Ctx, editor: ^Editor) {

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
			editor.tab = ui.segmented_control(ctx, "toolbar:tabs", editor.tab, toolbar_tabs)
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
