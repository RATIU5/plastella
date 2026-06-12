package editor

import clay "../../vendor/clay"
import "../ui"
import rl "vendor:raylib"

SIDEBAR_MIN: f32 : 150
SIDEBAR_MAX: f32 : 500
RESIZE_HANDLE: f32 : 8

sidebar_update :: proc() {
	assert(editor_ctx != nil, "editor_ctx not initialized")
	mx := f32(rl.GetMouseX())
	border_x := editor_ctx.sidebar_width
	near := abs(mx - border_x) <= RESIZE_HANDLE

	rl.SetMouseCursor(.RESIZE_EW if (near || editor_ctx.sidebar_resizing) else .DEFAULT)

	if near && rl.IsMouseButtonPressed(.LEFT) {
		editor_ctx.sidebar_resizing = true
	}
	if rl.IsMouseButtonReleased(.LEFT) {
		editor_ctx.sidebar_resizing = false
	}

	if editor_ctx.sidebar_resizing {
		editor_ctx.sidebar_width = clamp(mx, SIDEBAR_MIN, SIDEBAR_MAX)
	}
}

sidebar_draw :: proc() {
	if clay.UI(clay.ID("HelloText"))(
	{
		layout = {
			sizing = {
				width = clay.SizingFixed(editor_ctx.sidebar_width),
				height = clay.SizingFit({min = cast(f32)rl.GetScreenHeight()}),
			},
			childAlignment = {y = .Center},
			padding = {left = 50, right = 50},
		},
		backgroundColor = ui.COLOR_SIDEBAR,
		border = {color = ui.COLOR_SIDEBAR_BORDER, width = {right = 1}},
	},
	) {
		clay.Text(
			"Hello, World",
			{
				fontSize = 14,
				fontId = u16(ui.FONT.BODY_REG_14),
				textColor = ui.rl_color_to_clay_color(rl.WHITE),
			},
		)
	}
}
