package editor

import "../../vendor/clay"
import "../config"
import "../gfx"
import "../ui"
import "./editor_types"


toolbar_frame :: proc(ctx: ^ui.Ctx, edtr: ^editor_types.Editor) {
	toolbar_tabs := [editor_types.Toolbar_Tab]ui.Tab {
		.Project = {id = "toolbar:tab:project", label = "Project"},
		.Map = {id = "toolbar:tab:map", label = "Map", disabled = !edtr.project.initialized},
		.Tileset = {
			id = "toolbar:tab:tileset",
			label = "Tileset",
			disabled = !edtr.project.initialized,
		},
		.Sprites = {
			id = "toolbar:tab:sprites",
			label = "Sprites",
			disabled = !edtr.project.initialized,
		},
		.Level = {id = "toolbar:tab:level", label = "Level", disabled = !edtr.project.initialized},
		.Settings = {
			id = "toolbar:tab:settings",
			label = "Settings",
			disabled = !edtr.project.initialized,
		},
	}

	window_title := "Plastella" if !edtr.project.initialized else edtr.project.name

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
			ui.text(ctx.frame.assets, window_title, .UI_BLD_13, {255, 255, 255, 255})
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
			edtr.tab = ui.segmented_control(ctx, "toolbar:tabs", edtr.tab, toolbar_tabs)
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
			// TODO
		}
	}
}
