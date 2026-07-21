package ui

import clay "../../vendor/clay"
import platform "../platform"
import render "../render"
import "core:math"
import "core:strings"
import "core:unicode/utf8"

Text_Buffer :: [dynamic]u8

Text_Input_State :: struct {
	buf:            Text_Buffer,
	caret:          int,
	select_anchor:  int,
	scroll_x:       f32,
	blink:          f32,
	cached_caret_x: f32,
	caret_x_dirty:  bool,
}

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

INPUT :: enum u8 {
	DEFAULT,
}

input_styles := [INPUT]Input_Style {
	.DEFAULT = {
		font = .UI_REG_14,
		padding = {top = 5, left = 5, right = 5, bottom = 5},
		bg_color = {
			.Normal = GREY_805,
			.Hover = GREY_760,
			.Active = GREY_805,
			.Engaged = GREY_805,
			.Engaged_Hover = GREY_760,
			.Engaged_Active = GREY_805,
			.Disabled = GREY_850,
		},
		fg_color = {
			.Normal = GREY_290,
			.Hover = GREY_240,
			.Active = GREY_340,
			.Engaged = GREY_290,
			.Engaged_Hover = GREY_240,
			.Engaged_Active = GREY_340,
			.Disabled = GREY_500,
		},
		border_color = {
			.Normal = GREY_710,
			.Hover = GREY_660,
			.Active = GREY_760,
			.Engaged = GREY_290,
			.Engaged_Hover = GREY_240,
			.Engaged_Active = GREY_340,
			.Disabled = GREY_805,
		},
		ph_color = GREY_445,
		border_width = {top = 1, left = 1, right = 1, bottom = 1},
		radius = {topLeft = 5, topRight = 5, bottomLeft = 5, bottomRight = 5},
	},
}

@(private)
input_state_get :: proc(id: string) -> (^Text_Input_State, string) {
	s, found := &ui_mem.input_states[id]
	key := id
	if !found {
		key = strings.clone(id)
		s = map_insert(&ui_mem.input_states, key, Text_Input_State{caret_x_dirty = true})
	} else {
		for k in ui_mem.input_states {
			if k == id {
				key = k
				break
			}
		}
	}
	return s, key
}

glyph_advance :: proc(
	st: render.Text_Style,
	cp: rune,
	font_size: i32,
	recs: [^]render.Rectangle,
) -> f32 {
	g := render.get_glyph_info(st.font, cp)
	idx := render.get_glyph_index(st.font, cp)
	adv := g.advanceX != 0 ? f32(g.advanceX) : recs[idx].width
	return adv * f32(st.size) / f32(font_size) + f32(st.letter_spacing)
}

measure_to :: proc(st: render.Text_Style, b: ^Text_Buffer, caret_byte: int) -> f32 {
	x := f32(0)
	i := 0
	font := render.get_font(st.font)
	recs := ([^]render.Rectangle)(font.recs)
	for i < caret_byte && i < len(b) {
		cp, size := utf8.decode_rune(b[i:])
		x += glyph_advance(st, cp, font.baseSize, recs)
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
	font := render.get_font(st.font)
	recs := ([^]render.Rectangle)(font.recs)
	for i < len(b) {
		cp, size := utf8.decode_rune(b[i:])
		adv := glyph_advance(st, cp, font.baseSize, recs)
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
	_, size := utf8.decode_last_rune(s.buf[:s.caret])
	s.caret -= size
	mark_dirty(s)
}

delete_backward :: proc(s: ^Text_Input_State) {
	if s.caret <= 0 do return
	_, size := utf8.decode_last_rune(s.buf[:s.caret])
	remove_range(&s.buf, s.caret - size, s.caret)
	s.caret -= size
	s.select_anchor = s.caret
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
		if ch < 0x20 || ch == 0x7F do continue
		bytes, n := utf8.encode_rune(ch)
		replace_selection(s, bytes[:n])
	}

	if platform.key_press(.LEFT) || platform.key_press_repeat(.LEFT) {
		if ctrl {
			move_caret_to(s, word_left(&s.buf, s.caret), shift)
		} else if has_sel(s) && !shift {
			move_caret_to(s, sel_lo(s), false)
		} else {
			caret_left(s)
			if !shift do s.select_anchor = s.caret
		}
	}

	if platform.key_press(.RIGHT) || platform.key_press_repeat(.RIGHT) {
		if ctrl {
			move_caret_to(s, word_right(&s.buf, s.caret), shift)
		} else if has_sel(s) && !shift {
			move_caret_to(s, sel_hi(s), false)
		} else {
			caret_right(s)
			if !shift do s.select_anchor = s.caret
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
		clip := platform.get_clipboard() // raylib-owned; do not free
		if clip != "" {
			clean := make([dynamic]u8, 0, len(clip), context.temp_allocator)
			for ch in clip { 	// rune iteration; invalid bytes come out as RUNE_ERROR
				if ch < 0x20 || ch == 0x7F || ch == utf8.RUNE_ERROR do continue
				b, n := utf8.encode_rune(ch)
				append(&clean, ..b[:n])
			}
			if len(clean) > 0 do replace_selection(s, clean[:])
		}
	}
}

input_handle_mouse :: proc(
	s: ^Text_Input_State,
	st: render.Text_Style,
	box: clay.BoundingBox,
	pad_x: f32,
	focus: bool,
) {
	m := platform.mouse_pos()
	inside := m.x >= box.x && m.x < box.x + box.width && m.y >= box.y && m.y < box.y + box.height

	if platform.mouse_press(.LEFT) && inside {
		local_x := m.x - box.x - pad_x + s.scroll_x
		hit := index_from_x(st, &s.buf, local_x)
		s.caret = hit
		s.select_anchor = hit
		mark_dirty(s)
	}

	if focus && platform.mouse_down(.LEFT) && !platform.mouse_press(.LEFT) {
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
	text_w := measure_to(st, &s.buf, len(s.buf))
	s.scroll_x = clamp(s.scroll_x, 0, max(0, text_w - box_inner_width + PAD))
}

input_text :: proc(
	id: string,
	placeholder: string,
	theme: INPUT,
	width: Sizing = .FIT,
	height: Sizing = .FIT,
	disabled := false,
) {
	s, key := input_state_get(id)
	focus := ui_mem.focused_input == key
	hover := !disabled && render.pointer_over(id)
	active := !disabled && render.active_over(id)

	st := color_state(active, hover, focus, disabled)
	style := input_styles[theme]
	ts := render.text_styles[style.font]
	fg := style.fg_color[st]
	bg := style.bg_color[st]
	br := style.border_color[st]


	lo_x: f32 = 0
	hi_x: f32 = 0
	if focus && has_sel(s) {
		lo_x = measure_to(ts, &s.buf, sel_lo(s))
		hi_x = measure_to(ts, &s.buf, sel_hi(s))
	}

	if hover do platform.set_cursor(.IBEAM)

	box, box_found := render.element_bbox(id)
	pad_x := f32(style.padding.left)
	inner_width := box.width - f32(style.padding.left + style.padding.right)

	if box_found do input_handle_mouse(s, ts, box, pad_x, focus)
	if active {
		ui_mem.focused_input = id
	} else if platform.mouse_press(.LEFT) && focus {
		ui_mem.focused_input = ""
	}
	focus = ui_mem.focused_input == id

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
		{
			layout = {
				sizing = {
					width = clay.SizingGrow(),
					height = clay.SizingFixed(f32(ts.line_height)),
				},
			},
			clip = {horizontal = true},
		},
		) {
			if focus && has_sel(s) {
				if clay.UI(clay.ID(id, 2))(
				{
					floating = {
						attachTo = .Parent,
						clipTo = .AttachedParent,
						zIndex = 1,
						attachment = {element = .LeftTop, parent = .LeftTop},
						offset = {lo_x - s.scroll_x, 0},
						pointerCaptureMode = .Passthrough,
					},
					layout = {
						sizing = {
							width = clay.SizingFixed(hi_x - lo_x),
							height = clay.SizingFixed(f32(ts.size)),
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
					pointerCaptureMode = .Passthrough,
				},
			},
			) {
				if len(s.buf) > 0 {
					render.text(string(s.buf[:]), style.font, fg, .Left, .None)
				} else {
					render.text(placeholder, style.font, style.ph_color, .Left, .None)
				}
			}

			if focus && blink_on(s) && !has_sel(s) {
				if clay.UI(clay.ID(id, 4))(
				{
					floating = {
						attachTo = .Parent,
						clipTo = .AttachedParent,
						zIndex = 3,
						attachment = {element = .LeftTop, parent = .LeftTop},
						offset = {caret_x(ts, s) - s.scroll_x, 0},
						pointerCaptureMode = .Passthrough,
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

// Returned string aliases internal storage; clone to keep past this frame.
input_text_get :: proc(id: string) -> string {
	return string(ui_mem.input_states[id].buf[:])
}

input_text_set :: proc(id, val: string) {
	s, _ := input_state_get(id)
	clear(&s.buf)
	append(&s.buf, val)
	s.caret = min(s.caret, len(s.buf))
	s.select_anchor = s.caret
	mark_dirty(s)
}

input_destroy :: proc(id: string) {
	for key in ui_mem.input_states {
		if key == id {
			delete(ui_mem.input_states[key].buf)
			delete_key(&ui_mem.input_states, key)
			delete(key)
			break
		}
	}
	if ui_mem.focused_input == id do ui_mem.focused_input = ""
}

input_shutdown :: proc() {
	for key, s in ui_mem.input_states {
		delete(s.buf)
		delete(key)
	}
	delete(ui_mem.input_states)
	free(ui_mem)
	ui_mem = nil
}
