package ui

import clay "../../vendor/clay"
import api "../api"

Button_Style :: struct {
	bg:        clay.Color,
	bg_hover:  clay.Color,
	text:      clay.Color,
	padding:   clay.Padding,
	radius:    f32,
	font:      FONT,
	font_size: u16,
}


PRIMARY_BUTTON :: Button_Style {
	bg = COLOR_ACCENT,
	bg_hover = COLOR_ACCENT_HOVER,
	text = COLOR_TEXT,
	padding = {left = 16, right = 16, top = 8, bottom = 8},
	radius = 6,
	font = .BODY_REG_14,
	font_size = 14,
}

button :: proc(id: string, label: string, style: Button_Style, input: ^api.Input) -> bool {
	clicked := false
	if clay.UI(clay.ID(id))(
	{
		layout = {padding = style.padding, childAlignment = {x = .Center, y = .Center}},
		backgroundColor = clay.Hovered() ? style.bg_hover : style.bg,
		cornerRadius = clay.CornerRadius{style.radius, style.radius, style.radius, style.radius},
	},
	) {
		if clay.Hovered() {
			input.cursor = .Pointer
			if input.left_pressed && input.capture == api.CAPTURE_NONE {
				clicked = true
			}
		}
		clay.Text(
			label,
			{fontSize = style.font_size, fontId = u16(style.font), textColor = style.text},
		)
	}

	return clicked
}
