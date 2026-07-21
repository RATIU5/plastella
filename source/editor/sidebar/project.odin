package sidebar

import clay "../../../vendor/clay"
import project "../../project"
import ui "../../ui"

project_frame :: proc(prj: ^^project.Project_Memory) {
	if prj^ == nil {
		if clay.UI(clay.ID("sidebar:content:project"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = clay.LayoutDirection.TopToBottom,
				childAlignment = {clay.LayoutAlignmentX.Center, clay.LayoutAlignmentY.Center},
				childGap = 5,
			},
			clip = {horizontal = true},
		},
		) {
			if ui.button(
				"sidebar:content:project:new_project_btn",
				"New Project",
				.SIDEBAR_TEXT,
				sizing = 180,
			) {
				prj^ = project.project_init()
			}
			if ui.button(
				"sidebar:content:project:open_project_btn",
				"Open Project",
				.SIDEBAR_TEXT,
				sizing = 180,
				disabled = true,
			) {
				// TODO: Unimplemented
			}
		}
	} else {
		if clay.UI(clay.ID("sidebar:content:project"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				layoutDirection = clay.LayoutDirection.TopToBottom,
				childAlignment = {clay.LayoutAlignmentX.Left, clay.LayoutAlignmentY.Top},
				childGap = 5,
				padding = {top = 10},
			},
			clip = {horizontal = true},
		},
		) {
			ui.input_text("sidebar:content:project:text", "Enter something", .DEFAULT, .GROW)
			ui.input_text("sidebar:content:project:text2", "Enter something 2", .DEFAULT, .GROW)
		}
	}
}
