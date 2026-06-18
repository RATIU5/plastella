package ui_old

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

// Selection span of the focused input, low..high byte offsets (anchor/caret
// ordered). Equal ends mean an empty selection (just a caret).
@(private)
sel_range :: proc() -> (lo, hi: int) {
	lo, hi = state.sel_anchor, state.sel_caret
	if lo > hi do lo, hi = hi, lo
	return
}

// Collapse the selection to a caret at byte offset `idx`.
@(private)
selection_clear :: proc(idx: int) {
	state.sel_anchor = idx
	state.sel_caret = idx
}

// Drop bytes [lo, hi) from a buffer, shifting the tail down.
@(private)
remove_bytes :: proc(buf: ^[dynamic]u8, lo, hi: int) {
	n := len(buf^)
	a, b := clamp(lo, 0, n), clamp(hi, 0, n)
	if b <= a do return
	copy(buf[a:], buf[b:])
	resize(buf, n - (b - a))
}

// Insert `data` at byte offset `at`, shifting the tail up. copy handles the
// overlapping move (memmove semantics).
@(private)
insert_bytes :: proc(buf: ^[dynamic]u8, at: int, data: []u8) {
	if len(data) == 0 do return
	n := len(buf^)
	resize(buf, n + len(data))
	copy(buf[at + len(data):], buf[at:n])
	copy(buf[at:], data)
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
		// Escape drops focus and clears the selection, leaving the buffer as-is.
		if input.escape && state.focused_input == eid.id {
			state.focused_input = 0
			selection_clear(0)
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

		// Map mouse x to a caret slot in the text. A press sets both ends
		// (collapsed caret); dragging with the mouse held moves only the caret,
		// growing the selection from the anchor.
		if focused && owns {
			data := clay.GetElementData(eid)
			if data.found {
				cur := strings.to_string(value^)
				local_x := input.mouse.x - data.boundingBox.x - f32(style.padding.left)
				idx := text_index_at(cur, .REG_16, local_x)
				if input.left_pressed {
					state.sel_anchor = idx
					state.sel_caret = idx
					state.focus_time = input.time // keep caret solid on click
				} else if input.left_down && idx != state.sel_caret {
					state.sel_caret = idx
					state.focus_time = input.time // and while dragging
				}
			}
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

	// Edit the caller's buffer at the caret while focused. Typing or deleting
	// resets the blink so the caret stays solid through the keystroke.
	if focused {
		caret := clamp(state.sel_caret, 0, len(value.buf))

		// Any edit first removes the active selection, leaving the caret at its
		// start — so typing replaces it and backspace just clears it.
		lo, hi := sel_range()
		edited := input.char_count > 0 || input.backspace || input.delete_forward
		if edited && hi > lo {
			remove_bytes(&value.buf, lo, hi)
			caret = lo
		}

		// Insert typed runes at the caret, advancing past each.
		for r in input.chars[:input.char_count] {
			b, n := utf8.encode_rune(r)
			insert_bytes(&value.buf, caret, b[:n])
			caret += n
		}

		// Backspace deletes left of the caret: whole, word, or one rune.
		if input.backspace && hi <= lo && caret > 0 {
			s := strings.to_string(value^)
			start := caret
			switch {
			case input.backspace_all:
				start = 0
			case input.backspace_word:
				for start > 0 && s[start - 1] == ' ' do start -= 1
				for start > 0 && s[start - 1] != ' ' do start -= 1
			case:
				_, w := utf8.decode_last_rune_in_string(s[:caret])
				start = caret - w
			}
			remove_bytes(&value.buf, start, caret)
			caret = start
		}

		// Forward delete erases the rune to the right of the caret (caret stays).
		if input.delete_forward && hi <= lo && caret < len(value.buf) {
			s := strings.to_string(value^)
			_, w := utf8.decode_rune_in_string(s[caret:])
			remove_bytes(&value.buf, caret, caret + w)
		}

		if edited {
			state.focus_time = input.time
			selection_clear(caret) // collapse selection to the new caret
		}
	}

	str := strings.to_string(value^)

	// Queue the selection highlight + caret. Box is last frame's (GetElementData
	// lags layout by a frame) — fine here. .found guards the first frame before
	// this id is laid out. Both are painted after clay in cursor_flush.
	if focused {
		data := clay.GetElementData(eid)
		if data.found {
			tx := data.boundingBox.x + f32(style.padding.left)
			ty := data.boundingBox.y + f32(style.padding.top)
			lo, hi := sel_range()
			lo, hi = clamp(lo, 0, len(str)), clamp(hi, 0, len(str))

			// Mirror the highlighted substring into the staging buffer.
			strings.builder_reset(&state.selection)
			strings.write_string(&state.selection, str[lo:hi])

			if hi > lo {
				x0 := tx + text_width(str[:lo], .REG_16)
				x1 := tx + text_width(str[:hi], .REG_16)
				selection_set(x0, ty, x1 - x0, f32(style.font_size))
			}
			if cursor_visible(input.time - state.focus_time) {
				caret := clamp(state.sel_caret, 0, len(str))
				cursor_set(tx + text_width(str[:caret], .REG_16), ty, f32(style.font_size))
			}
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
