package ui

import clay "../../vendor/clay"
import platform "../platform"
import render "../render"
import "core:math"
import "core:unicode/utf8"

Text_Buffer :: [dynamic]u8

Input_Style :: struct {
	font:         render.TEXT,
	padding:      clay.Padding,
	border_width: clay.BorderWidth,
	border_color: [Color_State]clay.Color,
	bg_color:     [Color_State]clay.Color,
	fg_color:     [Color_State]clay.Color,
	ph_color:     clay.Color,
	radius:       clay.CornerRadius,
}

Text_Input_State :: struct {
	buf:            Text_Buffer,
	caret:          int,
	select_anchor:  int,
	scroll_x:       f32,
	blink:          f32,
	active:         bool,
	cached_caret_x: f32,
	caret_x_dirty:  bool,
	seen_frame:     u64,
}

INPUT :: enum u8 {
	DEFAULT,
}

input_styles := [INPUT]Input_Style {
	.DEFAULT = {},
}

@(private)
input_states: map[string]Text_Input_State
@(private)
focused_input: string
@(private)
ui_frame: u64

@(private)
input_get_state :: proc(id: string) -> ^Text_Input_State {
	s, found := &input_states[id]
	if !found {
		input_states[id] = Text_Input_State {
			caret_x_dirty = true,
		}
		s = &input_states[id]
	}
	s.seen_frame = ui_frame
	return s
}

glyph_advance :: proc(st: render.Text_Style, cp: rune) -> f32 {
	font := render.get_font(st.font)
	g := render.get_glyph_info(st.font, cp)
	idx := render.get_glyph_index(st.font, cp)
	adv := g.advanceX != 0 ? f32(g.advanceX) : font.recs[idx].width
	return adv * f32((i32(st.size) / font.baseSize)) + f32(st.letter_spacing)
}

measure_to :: proc(st: render.Text_Style, b: ^Text_Buffer, caret_byte: int) -> f32 {
	x := f32(0)
	i := 0
	for i < caret_byte && i < len(b) {
		cp, size := utf8.decode_rune(b[i:])
		x += glyph_advance(st, cp)
		i += size
	}
	return x
}

caret_x :: proc(st: render.Text_Style, s: ^Text_Input_State) -> f32 {
	if s.caret_x_dirty {
		s.cached_caret_x = measure_to(st, &s.buf, s.caret)
		s.caret_x_dirty = false
	}
	return s.cached_caret_x
}

mark_dirty :: proc(s: ^Text_Input_State) {
	s.caret_x_dirty = true
	s.blink = 0
}

index_from_x :: proc(st: render.Text_Style, b: ^Text_Buffer, target_x: f32) -> int {
	x := f32(0)
	i := 0
	for i < len(b) {
		cp, size := utf8.decode_rune(b[i:])
		adv := glyph_advance(st, cp)
		if target_x < x + adv * 0.5 do return i
		x += adv
		i += size
	}
	return len(b)
}

caret_right :: proc(s: ^Text_Input_State) {
	if s.caret >= len(s.buf) do return
	_, size := utf8.decode_rune(s.buf[s.caret:])
	s.caret += size
	mark_dirty(s)
}

caret_left :: proc(s: ^Text_Input_State) {
	if s.caret <= 0 do return
	_, size := utf8.decode_rune(s.buf[:s.caret])
	s.caret -= size
	mark_dirty(s)
}

delete_backward :: proc(s: ^Text_Input_State) {
	if s.caret <= 0 do return
	_, size := utf8.decode_last_rune(s.buf[:s.caret])
	remove_range(&s.buf, s.caret - size, s.caret)
	s.caret -= size
	mark_dirty(s)
}

delete_forward :: proc(s: ^Text_Input_State) {
	if s.caret >= len(s.buf) do return
	_, size := utf8.decode_rune(s.buf[s.caret:])
	remove_range(&s.buf, s.caret, s.caret + size)
	mark_dirty(s)
}

blink_on :: proc(s: ^Text_Input_State) -> bool {
	PERIOD :: f32(1.0)
	return math.mod(s.blink, PERIOD) < PERIOD * 0.5
}

has_sel :: proc(s: ^Text_Input_State) -> bool {
	return s.select_anchor != s.caret
}

sel_lo :: proc(s: ^Text_Input_State) -> int {
	return min(s.select_anchor, s.caret)
}

sel_hi :: proc(s: ^Text_Input_State) -> int {
	return max(s.select_anchor, s.caret)
}

delete_selection :: proc(s: ^Text_Input_State) {
	if !has_sel(s) do return
	lo, hi := sel_lo(s), sel_hi(s)
	remove_range(&s.buf, lo, hi)
	s.caret = lo
	s.select_anchor = lo
	mark_dirty(s)
}

replace_selection :: proc(s: ^Text_Input_State, ins: []u8) {
	delete_selection(s)
	inject_at(&s.buf, s.caret, ..ins)
	s.caret += len(ins)
	s.select_anchor = s.caret
	mark_dirty(s)
}

move_caret_to :: proc(s: ^Text_Input_State, new_caret: int, shift_held: bool) {
	s.caret = new_caret
	if !shift_held do s.select_anchor = s.caret
	mark_dirty(s)
}

key_backspace :: proc(s: ^Text_Input_State) {
	if has_sel(s) {
		delete_selection(s)
	} else {
		delete_backward(s)
	}
}

key_delete :: proc(s: ^Text_Input_State) {
	if has_sel(s) {
		delete_selection(s)
	} else {
		delete_forward(s)
	}
}

is_space_cp :: proc(cp: rune) -> bool {
	return cp == ' ' || cp == '\t' || cp == '\n'
}

word_left :: proc(b: ^Text_Buffer, from: int) -> int {
	i := from
	for i > 0 {
		cp, size := utf8.decode_last_rune(b[:i])
		if !is_space_cp(cp) do break
		i -= size
	}
	for i > 0 {
		cp, size := utf8.decode_last_rune(b[:i])
		if is_space_cp(cp) do break
		i -= size
	}
	return i
}

word_right :: proc(b: ^Text_Buffer, from: int) -> int {
	i := from
	for i < len(b) {
		cp, size := utf8.decode_rune(b[i:])
		if is_space_cp(cp) do break
		i += size
	}
	for i < len(b) {
		cp, size := utf8.decode_rune(b[i:])
		if !is_space_cp(cp) do break
		i += size
	}
	return i
}

clipboard_copy :: proc(s: ^Text_Input_State) {
	lo, hi := sel_lo(s), sel_hi(s)
	sel := string(s.buf[lo:hi])
	platform.set_clipboard(sel)
}

input_handle_keys :: proc(s: ^Text_Input_State, st: render.Text_Style) {
	shift := platform.key_down(.LEFT_SHIFT) || platform.key_down(.RIGHT_SHIFT)
	when ODIN_OS == .Darwin {
		ctrl := platform.key_down(.LEFT_SUPER) || platform.key_down(.RIGHT_SUPER)
	} else {
		ctrl := platform.key_down(.LEFT_CONTROL) || platform.key_down(.RIGHT_CONTROL)
	}

	for ch in platform.chars_typed() {
		bytes, n := utf8.encode_rune(ch)
		replace_selection(s, bytes[:n])
	}

	if platform.key_press(.LEFT) || platform.key_press_repeat(.LEFT) {
		if ctrl {
			move_caret_to(s, word_left(&s.buf, s.caret), shift)
		} else if has_sel(s) && !shift {
			move_caret_to(s, sel_lo(s), false)
		} else {
			c := s.caret
			if c > 0 {
				_, size := utf8.decode_last_rune(s.buf[:c])
				c -= size
			}
			move_caret_to(s, c, shift)
		}
	}

	if platform.key_press(.RIGHT) || platform.key_press_repeat(.RIGHT) {
		if ctrl {
			move_caret_to(s, word_right(&s.buf, s.caret), shift)
		} else if has_sel(s) && !shift {
			move_caret_to(s, sel_hi(s), false)
		} else {
			c := s.caret
			if c < len(s.buf) {
				_, size := utf8.decode_last_rune(s.buf[c:])
				c += size
			}
			move_caret_to(s, c, shift)
		}
	}

	if platform.key_press(.HOME) || platform.key_press_repeat(.HOME) do move_caret_to(s, 0, shift)
	if platform.key_press(.END) || platform.key_press_repeat(.END) do move_caret_to(s, len(s.buf), shift)

	if platform.key_press(.BACKSPACE) || platform.key_press_repeat(.BACKSPACE) {
		if ctrl && !has_sel(s) {
			to := word_left(&s.buf, s.caret)
			remove_range(&s.buf, to, s.caret)
			s.caret = to
			s.select_anchor = to
			mark_dirty(s)
		} else {
			key_backspace(s)
		}
	}

	if platform.key_press(.DELETE) || platform.key_press_repeat(.DELETE) {
		if ctrl && !has_sel(s) {
			to := word_right(&s.buf, s.caret)
			remove_range(&s.buf, s.caret, to)
			s.select_anchor = s.caret
			mark_dirty(s)
		} else {
			key_delete(s)
		}
	}

	if ctrl && platform.key_press(.A) {
		s.select_anchor = 0
		s.caret = len(s.buf)
		mark_dirty(s)
	}
	if ctrl && platform.key_press(.C) && has_sel(s) {
		clipboard_copy(s)
	}
	if ctrl && platform.key_press(.X) && has_sel(s) {
		clipboard_copy(s)
		delete_selection(s)
	}
	if ctrl && (platform.key_press(.V) || platform.key_press_repeat(.V)) {
		clip := platform.get_clipboard()
		if clip != "" {
			// TODO: strip '/n' from text before replacing
			replace_selection(s, transmute([]u8)clip)
		}
	}
}

input_handle_mouse :: proc(
	s: ^Text_Input_State,
	st: render.Text_Style,
	box: clay.BoundingBox,
	pad_x: f32,
) {
	m := platform.mouse_pos()
	inside := m.x >= box.x && m.x < box.x + box.width && m.y >= box.y && m.y < box.y + box.height

	if platform.mouse_press(.LEFT) {
		s.active = inside
		if inside {
			local_x := m.x - box.x - pad_x + s.scroll_x
			hit := index_from_x(st, &s.buf, local_x)
			s.caret = hit
			s.select_anchor = hit
			mark_dirty(s)
		}
	}

	if s.active && platform.mouse_down(.LEFT) && !platform.mouse_press(.LEFT) {
		local_x := m.x - box.x - pad_x + s.scroll_x
		hit := index_from_x(st, &s.buf, local_x)
		if hit != s.caret {
			s.caret = hit
			mark_dirty(s)
		}
	}
}

ensure_caret_visible :: proc(s: ^Text_Input_State, st: render.Text_Style, box_inner_width: f32) {
	cx := caret_x(st, s)
	PAD :: f32(2)
	if cx - s.scroll_x < PAD {
		s.scroll_x = cx - PAD
	} else if cx - s.scroll_x > box_inner_width - PAD {
		s.scroll_x = cx - (box_inner_width - PAD)
	}
	s.scroll_x = max(s.scroll_x, 0)
}

input_text :: proc(
	id: string,
	value: string,
	placeholder: string,
	theme: INPUT,
	width: Sizing = .FIT,
	height: Sizing = .FIT,
	disabled := false,
) {
	s := input_get_state(id)
	focus := focused_input == id
	hover := !disabled && render.pointer_over(id)
	active := !disabled && render.active_over(id)

	st := color_state(active, hover, focus, disabled)
	style := input_styles[theme]
	ts := render.text_styles[style.font]
	fg := style.fg_color[st]
	bg := style.bg_color[st]
	br := style.border_color[st]
	lo_x := measure_to(ts, &s.buf, sel_lo(s))
	hi_x := measure_to(ts, &s.buf, sel_hi(s))

	if hover do platform.set_cursor(.IBEAM)

	box, box_found := render.element_bbox(id)
	pad_x := f32(style.padding.left)
	inner_width := box.width - f32(style.padding.left + style.padding.right)

	input_handle_mouse(s, ts, box, pad_x)
	if s.active do focused_input = id
	if platform.mouse_press(.LEFT) && !s.active && focus do focused_input = ""

	if focus {
		s.blink += platform.delta_time()
		input_handle_keys(s, ts)
		if box_found do ensure_caret_visible(s, ts, inner_width)
	}

	if clay.UI(clay.ID(id))(
	{
		layout = {
			padding = style.padding,
			sizing = sizing_to_clay(width, height),
			childAlignment = {y = .Center},
		},
		border = {width = style.border_width, color = br},
		backgroundColor = bg,
		cornerRadius = style.radius,
	},
	) {
		if clay.UI(clay.ID(id, 1))(
		{layout = {sizing = {width = clay.SizingGrow()}}, clip = {horizontal = true}},
		) {
			if s.active && has_sel(s) {
				if clay.UI(clay.ID(id, 2))(
				{
					floating = {
						attachTo = .Parent,
						clipTo = .AttachedParent,
						zIndex = 1,
						attachment = {element = .LeftTop, parent = .LeftTop},
						offset = {lo_x - s.scroll_x, 0},
					},
					layout = {
						sizing = {
							width = clay.SizingFixed(hi_x - lo_x),
							height = clay.SizingGrow(),
						},
					},
					backgroundColor = opacity(ACCENT, 100),
				},
				) {}
			}

			if clay.UI(clay.ID(id, 3))(
			{
				floating = {
					attachTo = .Parent,
					clipTo = .AttachedParent,
					zIndex = 2,
					attachment = {element = .LeftTop, parent = .LeftTop},
					offset = {-s.scroll_x, 0},
				},
			},
			) {
				if len(s.buf) > 0 {
					render.text(string(s.buf[:]), style.font, fg, .Left, .None)
				} else {
					render.text(placeholder, style.font, style.ph_color, .Left, .None)
				}
			}

			if s.active && blink_on(s) && !has_sel(s) {
				if clay.UI(clay.ID(id, 4))(
				{
					floating = {
						attachTo = .Parent,
						clipTo = .AttachedParent,
						zIndex = 3,
						attachment = {element = .LeftTop, parent = .LeftTop},
						offset = {caret_x(ts, s) - s.scroll_x, 0},
					},
					layout = {
						sizing = {
							width = clay.SizingFixed(1.5),
							height = clay.SizingFixed(f32(ts.size)),
						},
					},
					backgroundColor = style.fg_color[.Normal],
				},
				) {}
			}
		}
	}
}

input_frame_end :: proc() {
	for id, &s in input_states {
		if s.seen_frame != ui_frame {
			delete(s.buf)
			delete_key(&input_states, id)
		}
	}
	ui_frame += 1
}
