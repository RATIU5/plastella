package app

import "../../vendor/clay"

TOOLBAR_LEFT_PAD :: clay.Padding{left = 90, right = 10, top = 10, bottom = 10}

toolbar_frame :: proc(ctx: ^Ctx, edtr: ^Editor) {
	toolbar_tabs := [Toolbar_Tab]Tab {
		.Project = {id = "toolbar:tab:project", content = "Project"},
		.Assets = {
			id = "toolbar:tab:assets",
			content = "Assets",
			disabled = !edtr.project.initialized,
		},
		.Scripts = {
			id = "toolbar:tab:scripts",
			content = "Scripts",
			disabled = !edtr.project.initialized,
		},
		.Level = {
			id = "toolbar:tab:level",
			content = "Level",
			disabled = !edtr.project.initialized,
		},
	}

	window_title := "Plastella" if !edtr.project.initialized else edtr.project.name

	if clay.UI(clay.ID("toolbar"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(TOOLBAR_HEIGHT)},
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
					width = clay.SizingPercent(1.0 / 3.0),
					height = clay.SizingFixed(TOOLBAR_HEIGHT),
				},
				layoutDirection = .LeftToRight,
				childAlignment = {x = .Left, y = .Center},
				padding = TOOLBAR_LEFT_PAD,
			},
		},
		) {
			// Known before layout, so the title can never widen the box that sizes it.
			width := max(
				1,
				ctx.frame.screen.x / 3 - f32(TOOLBAR_LEFT_PAD.left + TOOLBAR_LEFT_PAD.right),
			)

			text(
				ctx.frame.assets,
				window_title,
				.UI_BLD_13,
				{255, 255, 255, 255},
				ellipsize = width,
			)
		}

		// TOOLBAR:CENTER
		if clay.UI(clay.ID("toolbar:center"))(
		{
			layout = {
				sizing = {
					width = clay.SizingPercent(1.0 / 3.0),
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
					width = clay.SizingPercent(1.0 / 3.0),
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
