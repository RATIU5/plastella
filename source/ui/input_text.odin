package ui

import clay "../../vendor/clay"
import api "../api"

CAPTURE_INPUT_TEXT_BIT :: u64(2) << 32

Input_Text_State :: enum u8 {
	Normal,
	Hover,
	Focus,
	Disabled,
}

Input_Text_State_Type :: enum u8 {
	Base,
	Info,
	Success,
	Warning,
	Error,
}

Input_Text_Style :: struct {
	bg:           [Input_Text_State]clay.Color,
	fg:           [Input_Text_State]clay.Color,
	border:       [Input_Text_State]clay.Color,
	placeholder:  clay.Color,
	state_type:   Input_Text_State_Type,
	padding:      clay.Padding,
	radius:       clay.CornerRadius,
	border_width: clay.BorderWidth,
	font:         FONT,
	font_size:    u16,
	width_type:   WIDTH_TYPE,
}

Input_Text_Result :: struct {
	clicked: bool,
	hovered: bool,
	held:    bool,
	focused: bool,
}

@(private)
input_text_state :: proc(hovered, focused, disabled: bool) -> Input_Text_State {
	switch {
	case disabled:
		return .Disabled
	case focused:
		return .Focus
	case hovered:
		return .Hover
	case:
		return .Normal
	}
}

input_text :: proc(
	id: string,
	default_value: string,
	placeholder: string,
	style: Input_Text_Style,
	input: ^api.Input,
	index: u32 = 0,
	tooltip: Tooltip_Content = nil,
	disabled := false,
) -> Input_Text_Result {
	result: Input_Text_Result

	eid := clay.ID(id, index)
	cap := api.Capture(u64(eid.id) | CAPTURE_INPUT_TEXT_BIT)

	hovered := !disabled && clay.PointerOver(eid)
	focused := false

	if !disabled {
		result.hovered = hovered

		if hovered && input.left_pressed {
			api.capture_mouse(input, cap)
		}

		owns := api.has_capture(input, cap)
		result.held = owns && input.left_down
		focused = result.held && hovered

		if owns && input.left_released {
			if hovered {
				result.clicked = true
			}
			api.release_capture(input, cap)
		}

		if hovered {
			input.cursor = .Pointer

			if tooltip != nil {
				tooltip_set(eid, tooltip)
			}
		}
	} else if clay.PointerOver(eid) {
		input.cursor = .Not_Allowed
	}

	sizing := clay.Sizing {
		height = clay.SizingFit(),
		width  = clay.SizingFit(),
	}
	if style.width_type == .GROW {
		sizing.width = clay.SizingGrow()
	}

	st := input_text_state(hovered, focused, disabled)
	bg := style.bg[st]
	// fg := style.fg[st]
	bd := style.border[st]

	if clay.UI(clay.ID(id, index))(
	{
		layout = {
			padding = style.padding,
			childAlignment = {x = .Left, y = .Center},
			sizing = sizing,
		},
		border = {width = style.border_width, color = bd},
		backgroundColor = bg,
		cornerRadius = style.radius,
	},
	) {
		text(placeholder, .REG_16, style.placeholder)
	}

	return result
}
