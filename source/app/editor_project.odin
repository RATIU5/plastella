package app

import "../../vendor/clay"
import "core:strings"

@(private = "file")
project_name_validate :: proc(user_data: rawptr, text: string) -> (Input_Validity, string) {
	if len(strings.trim_space(text)) == 0 do return .Error, "Name can't be empty"
	return .None, ""
}

project_view :: proc(ctx: ^Ctx, edtr: ^Editor) {
	if edtr.project == nil do return

	if edtr.project.initialized {
		if edtr.tab == .Project {
			if clay.UI(clay.ID("area:project:settings"))(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
					padding = {10, 10, 10, 10},
					layoutDirection = .TopToBottom,
					childGap = 5,
				},
				cornerRadius = {10, 10, 10, 10},
				backgroundColor = COLOR_GREY_850,
			},
			) {
				text(ctx.frame.assets, "Project Name", .UI_REG_13, COLOR_GREY_340)
				res := text_input(
					ctx,
					"area:project:settings:name_input",
					&edtr.proj_name_input,
					"Untitled Project",
					validate = project_name_validate,
					width = 200,
					submit_on_enter = true,
				)
				if res.submitted && res.validity != .Error {
					project_rename(edtr.project, text_input_get(&edtr.proj_name_input))
				}
				switch {
				case res.validity != .None:
					text(ctx.frame.assets, res.message, .UI_REG_13, res.color)
				case res.at_limit:
					text(ctx.frame.assets, "Name is full", .UI_REG_13, COLOR_WARNING)
				}
			}
		}
	}

	// NO_PROJECT
	if !edtr.project.initialized {
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
				image(ctx, "area:no_project:logo", .Logo, 200)
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
					if btn, open := button(ctx, "area:no_project:button_new", .Wide_Action); open {
						if clay.UI(clay.ID("area:no_project:button_new:left"))(
						{layout = {sizing = {width = clay.SizingGrow()}, childGap = 6}},
						) {
							icon(ctx, "area:no_project:button_new:icon", .Add, 14, btn.fg)
							text(ctx.frame.assets, "New Project", btn.font, btn.fg, .Center, .None)
						}
						text(ctx.frame.assets, "Cmd + N", .UI_REG_12, btn.fg)

						if btn.clicked {
							project_init(edtr.project)
							text_input_set(&edtr.proj_name_input, project_name(edtr.project))
						}
					}
					if btn, open := button(ctx, "area:no_project:button_open", .Wide_Action);
					   open {
						if clay.UI(clay.ID("area:no_project:button_open:left"))(
						{layout = {sizing = {width = clay.SizingGrow()}, childGap = 6}},
						) {
							icon(ctx, "area:no_project:button_open:icon", .Project, 14, btn.fg)
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
