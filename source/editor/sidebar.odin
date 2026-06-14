package editor

import clay "../../vendor/clay"
import api "../api"
import "../ui"

SIDEBAR_MIN: f32 : 150
SIDEBAR_MAX: f32 : 500
RESIZE_HANDLE: f32 : 8
SIDEBAR_RESIZE_CAPTURE :: api.Capture(100)

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
				height = clay.SizingGrow({}),
			},
			childAlignment = {y = .Center},
			padding = {left = 12, right = 12},
		},
		backgroundColor = ui.COLOR_SIDEBAR,
		border = {color = ui.COLOR_SIDEBAR_BORDER, width = {right = 1}},
	},
	) {
		ui.button("Button", "Click Me", ui.PRIMARY_BUTTON, input)
	}
}
