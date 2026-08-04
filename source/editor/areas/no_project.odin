package area

import "../../../vendor/clay"
import "../../project"
import "../../ui"
import "../editor_types"

no_project :: proc(ctx: ^ui.Ctx, edtr: ^editor_types.Editor) {
	if edtr.project == nil || edtr.project.initialized do return

	if clay.UI(clay.ID("area:no_project"))(
	{
		layout = {
			sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
			layoutDirection = .TopToBottom,
			childAlignment = {x = .Center, y = .Center},
		},
	},
	) {
		if clay.UI(clay.ID("area:no_project:inner"))(
		{
			layout = {
				sizing = {width = clay.SizingFixed(250), height = clay.SizingPercent(0.5)},
				layoutDirection = .TopToBottom,
				childAlignment = {x = .Center, y = .Center},
				childGap = 20,
			},
		},
		) {
			ui.image(ctx, "area:no_project:logo", .Logo, 200)
			if clay.UI(clay.ID("area:no_project:quick_actions"))(
			{
				layout = {
					sizing = {width = clay.SizingGrow()},
					layoutDirection = .TopToBottom,
					childAlignment = {x = .Center, y = .Center},
					childGap = 8,
				},
			},
			) {
				if btn, open := ui.button(ctx, "area:no_project:button_new")(.WIDE_ACTION); open {
					if clay.UI(clay.ID("area:no_project:button_new:left"))(
					{layout = {sizing = {width = clay.SizingGrow()}, childGap = 6}},
					) {
						ui.icon(ctx, "area:no_project:button_new:icon", .Add, 14, btn.fg)
						ui.text(ctx.frame.assets, "New Project", btn.font, btn.fg, .Center, .None)
					}
					ui.text(ctx.frame.assets, "Cmd + N", .UI_REG_12, btn.fg)

					if btn.clicked {
						project.project_init(edtr.project)
					}
				}
				if btn, open := ui.button(ctx, "area:no_project:button_open")(.WIDE_ACTION); open {
					if clay.UI(clay.ID("area:no_project:button_open:left"))(
					{layout = {sizing = {width = clay.SizingGrow()}, childGap = 6}},
					) {
						ui.icon(ctx, "area:no_project:button_open:icon", .Project, 14, btn.fg)
						ui.text(ctx.frame.assets, "Open Project", btn.font, btn.fg, .Center, .None)
					}
					ui.text(ctx.frame.assets, "Cmd + O", .UI_REG_12, btn.fg)
				}
			}
		}
	}
}
