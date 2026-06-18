package ui

import clay "../../vendor/clay"
import api "../api"
import "core:strings"
import "core:unicode/utf8"

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
	width:        WIDTH,
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
	value: ^strings.Builder,
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

		// Focus follows the mouse: a press inside this input claims focus, a
		// press anywhere else releases it. Order-independent across inputs —
		// the one clicked sets focus to itself, every other focused input sees
		// a press it didn't receive and clears itself. Distinct from capture,
		// which is press-to-release drag ownership and dies on mouse-up.
		if input.left_pressed {
			if hovered {
				if state.focused_input != eid.id {
					state.focus_time = input.time // reset blink so the caret starts solid
				}
				state.focused_input = eid.id
			} else if state.focused_input == eid.id {
				state.focused_input = 0
			}
		}
		focused = state.focused_input == eid.id

		if hovered && input.left_pressed {
			api.capture_mouse(input, cap)
		}

		owns := api.has_capture(input, cap)
		result.held = owns && input.left_down

		if owns && input.left_released {
			if hovered {
				result.clicked = true
			}
			api.release_capture(input, cap)
		}

		if hovered {
			input.cursor = .Text

			if tooltip != nil {
				tooltip_set(eid, tooltip)
			}
		}
	} else if clay.PointerOver(eid) {
		input.cursor = .Not_Allowed
	}

	sizing := clay.Sizing {
		height = clay.SizingFit(),
		width  = clay.SizingGrow(),
	}
	if w, ok := style.width.(f32); ok {
		sizing.width = clay.SizingFixed(w)
	}

	result.focused = focused

	// Edit the caller's buffer while focused. Typing or deleting resets the
	// blink so the caret stays solid through the keystroke.
	if focused {
		for r in input.chars[:input.char_count] {
			strings.write_rune(value, r)
		}
		if input.backspace {
			s := strings.to_string(value^)
			if len(s) > 0 {
				switch {
				case input.backspace_all:
					resize(&value.buf, 0)
				case input.backspace_word:
					// Drop trailing spaces, then the word before the caret.
					end := len(s)
					for end > 0 && s[end - 1] == ' ' do end -= 1
					for end > 0 && s[end - 1] != ' ' do end -= 1
					resize(&value.buf, end)
				case:
					_, w := utf8.decode_last_rune_in_string(s)
					resize(&value.buf, len(value.buf) - w)
				}
			}
		}
		if input.char_count > 0 || input.backspace {
			state.focus_time = input.time
		}
	}

	str := strings.to_string(value^)

	// Queue the caret just past the text. Box is last frame's (GetElementData
	// lags layout by a frame) — fine for a blinking caret. .found guards the
	// first frame before this id is laid out.
	if focused && cursor_visible(input.time - state.focus_time) {
		data := clay.GetElementData(eid)
		if data.found {
			box := data.boundingBox
			x := box.x + f32(style.padding.left) + text_width(str, .REG_16)
			cursor_set(x, box.y + f32(style.padding.top), f32(style.font_size))
		}
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
		if len(str) > 0 {
			text(str, .REG_16, style.fg[st])
		} else {
			text(placeholder, .REG_16, style.placeholder)
		}
	}

	return result
}
