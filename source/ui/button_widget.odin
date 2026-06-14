package ui

import clay "../../vendor/clay"
import api "../api"

Button_Style :: struct {
	bg:           clay.Color,
	bg_hover:     clay.Color,
	text:         clay.Color,
	border:       clay.Color,
	padding:      clay.Padding,
	radius:       f32,
	border_width: u16,
	font:         FONT,
	font_size:    u16,
	width_type:   WIDTH_TYPE,
}


PRIMARY_BUTTON :: Button_Style {
	bg = COLOR_BUTTON_ACCENT,
	bg_hover = COLOR_BUTTON_ACCENT_HOVER,
	text = COLOR_BUTTON_TEXT,
	border = COLOR_BUTTON_BORDER,
	padding = {left = 16, right = 16, top = 8, bottom = 8},
	radius = 0.5,
	border_width = 1,
	font = .BODY_REG_14,
	font_size = 14,
	width_type = .FIT,
}

button :: proc(id: string, label: string, style: Button_Style, input: ^api.Input) -> bool {
	clicked := false
	sizing: clay.Sizing = clay.Sizing({height = clay.SizingFit(), width = clay.SizingFit()})
	border_width := clay.BorderAll(style.border_width)

	if style.width_type == .FIT {
		sizing.width = clay.SizingFit()
	} else if style.width_type == .GROW {
		sizing.width = clay.SizingGrow()
	}

	if clay.UI(clay.ID(id))(
	{
		layout = {
			padding = style.padding,
			childAlignment = {x = .Center, y = .Center},
			sizing = sizing,
		},
		border = {width = border_width, color = style.border},
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
