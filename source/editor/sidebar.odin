package editor

import clay "../../vendor/clay"
import api "../api"
import "../ui"

SIDEBAR_MIN: f32 : 250
SIDEBAR_MAX: f32 : 400
RESIZE_HANDLE: f32 : 4
SIDEBAR_RESIZE_CAPTURE :: api.Capture(100)
SIDEBAR_HEADER_HEIGHT: f32 : 32

Sidebar_State :: struct {
	width: f32,
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
			text_cfg := clay.TextElementConfig {
				fontSize  = 14,
				fontId    = u16(ui.FONT.BODY_BLD_14),
				textColor = ui.COLOR_TEXT,
				wrapMode  = clay.TextWrapMode.None,
			}

			project_name_id := clay.ID("Sidebar:ProjectName")
			if clay.UI(project_name_id)(
			{layout = {sizing = {width = clay.SizingFit(), height = clay.SizingFit()}}},
			) {
				clay.TextDynamic(
					ui.ellipsize_text("A Very Super Long Project Name", sb.width - 88, text_cfg),
					text_cfg,
				)
			}
			if clay.PointerOver(project_name_id) {
				ui.tooltip_set(project_name_id, "A Very Super Long Project Name")
			}
		}
		ui.button("Button", "Click Me", ui.PRIMARY_BUTTON, input)
		ui.button("ButtonIcon", ui.get_icon(.MAP), ui.ICON_BUTTON, input)
	}
}
