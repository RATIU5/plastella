package editor

import clay "../../vendor/clay"
import api "../api"
import "../project"
import textures "../render/textures"
import "../ui"
import "core:strings"

SIDEBAR_MIN: f32 : 250
SIDEBAR_MAX: f32 : 400
RESIZE_HANDLE: f32 : 4
SIDEBAR_RESIZE_CAPTURE :: api.Capture(100)
SIDEBAR_HEADER_HEIGHT: f32 : 32
SIDEBAR_FOOTER_HEIGHT: f32 : 38

Sidebar_Tab :: enum {
	Projects,
	Map,
	Tilesets,
	Sprites,
	LevelEditor,
	Settings,
}

Sidebar_State :: struct {
	width:        f32,
	tab:          Sidebar_Tab,
	project_name: strings.Builder,
}

sidebar :: proc(input: ^api.Input) {
	assert(editor_ctx != nil, "editor_ctx not initialized")
	sb := &editor_ctx.sidebar

	near := abs(input.mouse.x - sb.width) <= RESIZE_HANDLE
	resizing := api.has_capture(input, SIDEBAR_RESIZE_CAPTURE)

	if near && input.left_pressed {
		resizing = api.capture_mouse(input, SIDEBAR_RESIZE_CAPTURE)
	}
	if input.left_released {
		api.release_capture(input, SIDEBAR_RESIZE_CAPTURE)
		resizing = false
	}

	if near || resizing {
		input.cursor = .Resize_EW
	}
	if resizing {
		sb.width = clamp(input.mouse.x, SIDEBAR_MIN, SIDEBAR_MAX)
	}

	if clay.UI(clay.ID("Sidebar"))(
	{
		layout = {
			sizing = {
				width = clay.SizingFixed(editor_ctx.sidebar.width),
				height = clay.SizingGrow(),
			},
			layoutDirection = clay.LayoutDirection.TopToBottom,
		},
		backgroundColor = ui.COLOR_SIDEBAR,
		border = {
			color = near || resizing ? resizing ? ui.COLOR_SIDEBAR_BORDER_ACTIVE : ui.COLOR_SIDEBAR_BORDER_HOVER : ui.COLOR_SIDEBAR_BORDER,
			width = {right = 1},
		},
	},
	) {

		// Sidebar:Header
		if clay.UI(clay.ID("Sidebar:Header"))(
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
			// Sidebar:Header
			project_name_id := clay.ID("Sidebar:ProjectName")
			project_name := editor_ctx.project != nil ? editor_ctx.project.name : "Plastella"
			if clay.UI(project_name_id)(
			{layout = {sizing = {width = clay.SizingFit(), height = clay.SizingFit()}}},
			) {
			}
		}

		// Sidebar:Content
		sidebar_content_id := clay.ID("Sidebar:Content")
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

		// Sidebar:Footer
		sidebar_footer_id := clay.ID("Sidebar:Footer")
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
			ui.button("Button:Tab:Project", textures.UI_ICONS.PROJECT, .SIDEBAR_TAB)
			ui.button("Button:Tab:Map", textures.UI_ICONS.MAP, .SIDEBAR_TAB)
			ui.button("Button:Tab:Tileset", textures.UI_ICONS.TILESETS, .SIDEBAR_TAB)
			ui.button("Button:Tab:Sprites", textures.UI_ICONS.SPRITES, .SIDEBAR_TAB)
			ui.button("Button:Tab:Level_Editor", textures.UI_ICONS.LEVEL_EDITOR, .SIDEBAR_TAB)
			ui.button("Button:Tab:Settings", textures.UI_ICONS.SETTINGS, .SIDEBAR_TAB)
		}
	}
}
