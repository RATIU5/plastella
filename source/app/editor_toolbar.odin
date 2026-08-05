package app

import "../../vendor/clay"


toolbar_frame :: proc(ctx: ^Ctx, edtr: ^Editor) {
	toolbar_tabs := [Toolbar_Tab]Tab {
		.Project = {id = "toolbar:tab:project", content = "Project"},
		.Map = {id = "toolbar:tab:map", content = "Map", disabled = !edtr.project.initialized},
		.Tileset = {
			id = "toolbar:tab:tileset",
			content = "Tileset",
			disabled = !edtr.project.initialized,
		},
		.Sprites = {
			id = "toolbar:tab:sprites",
			content = "Sprites",
			disabled = !edtr.project.initialized,
		},
		.Level = {id = "toolbar:tab:level", content = "Level", disabled = !edtr.project.initialized},
		.Settings = {
			id = "toolbar:tab:settings",
			content = "Settings",
			disabled = !edtr.project.initialized,
		},
	}

	window_title := "Plastella" if !edtr.project.initialized else edtr.project.name

	if clay.UI(clay.ID("toolbar"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(TOOLBAR_HEIGHT)},
			// padding = {top = 10, left = 90},
		},
		backgroundColor = COLOR_GREY_850,
		border = {width = {bottom = 1}, color = COLOR_GREY_760},
	},
	) {
		// TOOLBAR:LEFT
		if clay.UI(clay.ID("toolbar:left"))(
		{
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(TOOLBAR_HEIGHT),
				},
				layoutDirection = .LeftToRight,
				childAlignment = {x = .Left, y = .Center},
				padding = {left = 90, right = 10, top = 10, bottom = 10},
			},
		},
		) {
			text(ctx.frame.assets, window_title, .UI_BLD_13, {255, 255, 255, 255})
		}

		// TOOLBAR:CENTER
		if clay.UI(clay.ID("toolbar:center"))(
		{
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(TOOLBAR_HEIGHT),
				},
				layoutDirection = .LeftToRight,
				childAlignment = {x = .Center, y = .Center},
				padding = {left = 10, right = 10, top = 10, bottom = 10},
			},
		},
		) {
			edtr.tab = segmented_control(ctx, "toolbar:tabs", edtr.tab, toolbar_tabs)
		}

		// TOOLBAR:RIGHT
		if clay.UI(clay.ID("toolbar:right"))(
		{
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(TOOLBAR_HEIGHT),
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
