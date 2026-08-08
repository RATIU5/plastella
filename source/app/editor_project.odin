package app

import "../../vendor/clay"
import "core:fmt"

project_view :: proc(ctx: ^Ctx, edtr: ^Editor) {
	if edtr.project == nil do return

	if edtr.project.initialized {
		if edtr.tab == .Project {
			if clay.UI(clay.ID("project:overview"))(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					padding = {10, 10, 10, 10},
					layoutDirection = .TopToBottom,
					childGap = 15,
				},
				cornerRadius = {10, 10, 10, 10},
				backgroundColor = COLOR_GREY_850,
			},
			) {

			}
			if clay.UI(clay.ID("project:settings"))(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					padding = {10, 10, 10, 10},
					layoutDirection = .TopToBottom,
					childGap = 10,
				},
				cornerRadius = {10, 10, 10, 10},
				backgroundColor = COLOR_GREY_850,
			},
			) {
				text(ctx.frame.assets, "Project Details", .UI_BLD_13, COLOR_GREY_150)
				if clay.UI(clay.ID("project:settings:project_name"))(
				{
					layout = {
						sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
						layoutDirection = .LeftToRight,
						childAlignment = {x = .Center, y = .Center},
						childGap = 10,
					},
				},
				) {
					if clay.UI(clay.ID("project:settings:project_name:left"))(
					{
						layout = {
							sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
							layoutDirection = .LeftToRight,
							childAlignment = {x = .Left, y = .Center},
						},
					},
					) {
						text(ctx.frame.assets, "Project Name", .UI_REG_13, COLOR_GREY_340)
					}
					res := text_input(
						ctx,
						"project:settings:name_input",
						&edtr.proj_name_input,
						{
							placeholder = "Untitled Project",
							width = f32(200),
							submit_on_enter = true,
						},
					)
					if res.submitted && res.validity != .Error {
						project_rename(edtr.project, text_input_get(&edtr.proj_name_input))
					}
					if res.validity != .None {
						status_text_set(edtr, fmt.tprintf("Project Name: %s", res.message))
					}
				}
			}
		}
	}

	// NO_PROJECT
	if !edtr.project.initialized {
		if clay.UI(clay.ID("no_project"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = .TopToBottom,
				childAlignment = {x = .Center, y = .Center},
			},
		},
		) {
			if clay.UI(clay.ID("no_project:inner"))(
			{
				layout = {
					sizing = {width = clay.SizingFixed(250), height = clay.SizingPercent(0.5)},
					layoutDirection = .TopToBottom,
					childAlignment = {x = .Center, y = .Center},
					childGap = 20,
				},
			},
			) {
				image(ctx, "no_project:logo", .Logo, 200)
				if clay.UI(clay.ID("no_project:quick_actions"))(
				{
					layout = {
						sizing = {width = clay.SizingGrow()},
						layoutDirection = .TopToBottom,
						childAlignment = {x = .Center, y = .Center},
						childGap = 8,
					},
				},
				) {
					if btn, open := button(ctx, "no_project:button_new", .Wide_Action); open {
						if clay.UI(clay.ID("no_project:button_new:left"))(
						{layout = {sizing = {width = clay.SizingGrow()}, childGap = 6}},
						) {
							icon(ctx, "no_project:button_new:icon", .Add, 14, btn.fg)
							text(ctx.frame.assets, "New Project", btn.font, btn.fg, .Center, .None)
						}
						text(ctx.frame.assets, "Cmd + N", .UI_REG_12, btn.fg)

						if btn.clicked {
							project_init(edtr.project)
							text_input_set(&edtr.proj_name_input, project_name(edtr.project))
						}
					}
					if btn, open := button(ctx, "no_project:button_open", .Wide_Action); open {
						if clay.UI(clay.ID("no_project:button_open:left"))(
						{layout = {sizing = {width = clay.SizingGrow()}, childGap = 6}},
						) {
							icon(ctx, "no_project:button_open:icon", .Project, 14, btn.fg)
							text(
								ctx.frame.assets,
								"Open Project",
								btn.font,
								btn.fg,
								.Center,
								.None,
							)
						}
						text(ctx.frame.assets, "Cmd + O", .UI_REG_12, btn.fg)
					}
				}
			}
		}
	}
}
