package editor

import clay "../../vendor/clay"
import platform "../platform"
import textures "../render/textures"
import ui "../ui"

SIDEBAR_MIN: f32 : 250
SIDEBAR_MAX: f32 : 400
SIDEBAR_WIDTH_DEFAULT: f32 : 250
SIDEBAR_HEADER_HEIGHT: f32 : 32
SIDEBAR_FOOTER_HEIGHT: f32 : 38
RESIZE_HANDLE: f32 : 4

Sidebar_Memory :: struct {
	width:    f32,
	resizing: bool,
}
sidebar_mem: ^Sidebar_Memory

sidebar_init :: proc() -> ^Sidebar_Memory {
	sidebar_mem = new(Sidebar_Memory)
	sidebar_mem.width = SIDEBAR_WIDTH_DEFAULT

	return sidebar_mem
}

sidebar_shutdown :: proc() {
	free(sidebar_mem)
	sidebar_mem = nil
}

sidebar_frame :: proc() {
	near := abs(platform.mouse_pos().x - sidebar_mem.width) <= RESIZE_HANDLE

	if near && platform.mouse_press(.LEFT) {
		sidebar_mem.resizing = true
	}
	if sidebar_mem.resizing && platform.mouse_release(.LEFT) {
		sidebar_mem.resizing = false
	}

	if near || sidebar_mem.resizing {
		platform.set_cursor(.RESIZE_EW)
	} else if platform.get_cursor() == .RESIZE_EW {
		platform.set_cursor(.DEFAULT)
	}
	if sidebar_mem.resizing {
		sidebar_mem.width = clamp(platform.mouse_pos().x, SIDEBAR_MIN, SIDEBAR_MAX)
	}

	if clay.UI(clay.ID("sidebar:group"))(
	{
		layout = {
			sizing = {width = clay.SizingFixed(sidebar_mem.width), height = clay.SizingGrow()},
			layoutDirection = clay.LayoutDirection.TopToBottom,
		},
		border = {
			width = {right = 1},
			color = near || sidebar_mem.resizing ? sidebar_mem.resizing ? ui.COLOR_SIDEBAR_BORDER_ACTIVE : ui.COLOR_SIDEBAR_BORDER_HOVER : ui.COLOR_SIDEBAR_BORDER,
		},
		backgroundColor = ui.COLOR_SIDEBAR,
	},
	) {

		// sidebar:header
		if clay.UI(clay.ID("sidebar:header"))(
		{
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(SIDEBAR_HEADER_HEIGHT),
				},
				childAlignment = {clay.LayoutAlignmentX.Left, clay.LayoutAlignmentY.Center},
				padding = {left = 82},
			},
			clip = {horizontal = true},
		},
		) {

		}

		// sidebar:content
		sidebar_content_id := clay.ID("sidebar:content")
		if clay.UI(sidebar_content_id)(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
				childAlignment = {clay.LayoutAlignmentX.Left, clay.LayoutAlignmentY.Top},
				layoutDirection = clay.LayoutDirection.TopToBottom,
				padding = {left = 5, right = 5},
			},
		},
		) {

		}

		// sidebar:footer
		sidebar_footer_id := clay.ID("sidebar:footer")
		if clay.UI(sidebar_footer_id)(
		{
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(SIDEBAR_FOOTER_HEIGHT),
				},
				padding = {left = 5, right = 5, top = 5, bottom = 5},
				childAlignment = {clay.LayoutAlignmentX.Left, clay.LayoutAlignmentY.Top},
				childGap = 3,
			},
			backgroundColor = ui.COLOR_SIDEBAR_FOOTER,
			border = {width = {top = 1}, color = ui.COLOR_SIDEBAR_BORDER},
		},
		) {
			ui.button("sidebar:footer:btn_project", textures.UI_ICONS.PROJECT, .SIDEBAR_TAB)
		}
	}
}
