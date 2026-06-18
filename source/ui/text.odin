package ui

import clay "../../vendor/clay"
import api "../api"
import "core:c"
import "core:mem"

Font_Style :: struct {
	size:           u16,
	id:             FONT,
	line_height:    u16,
	letter_spacing: u16,
}

text :: proc(
	text: string,
	style: Text_Style,
	color: clay.Color,
	text_alignment := clay.TextAlignment.Left,
	wrap_mode := clay.TextWrapMode.None,
	ellipsize_width: f32 = 0,
	user_data: rawptr = nil,
) {
	font_style := text_styles[style]
	font_cfg := clay.TextElementConfig {
		userData      = user_data,
		textColor     = color,
		fontId        = u16(font_style.id),
		fontSize      = font_style.size,
		letterSpacing = font_style.letter_spacing,
		lineHeight    = font_style.line_height,
		wrapMode      = wrap_mode,
		textAlignment = text_alignment,
	}

	if ellipsize_width > 0 {
		clay.Text(ellipsize_text(text, ellipsize_width, font_cfg), font_cfg)
	} else {
		clay.Text(text, font_cfg)
	}
}

// Rendered width of `s` in `style`, in points. Reuses the layout measure proc
// so it matches what clay draws.
text_width :: proc(s: string, style: Text_Style) -> f32 {
	fs := text_styles[style]
	cfg := clay.TextElementConfig {
		fontId        = u16(fs.id),
		fontSize      = fs.size,
		letterSpacing = fs.letter_spacing,
		lineHeight    = fs.line_height,
	}
	slice := clay.StringSlice {
		length = i32(len(s)),
		chars  = ([^]c.char)(raw_data(s)),
	}
	return measure_text(slice, &cfg, nil).width
}

// Byte offset in `s` whose rune boundary is nearest `local_x` (x measured from
// the text's left edge, in points). Used to map a mouse click to a caret slot.
// ponytail: O(n²) — re-measures each prefix; fine for single-line input fields.
text_index_at :: proc(s: string, style: Text_Style, local_x: f32) -> int {
	if local_x <= 0 do return 0
	prev_w: f32 = 0
	prev_i := 0
	for i := 1; i <= len(s); i += 1 {
		if i < len(s) && (s[i] & 0xC0) == 0x80 do continue // mid-rune byte
		w := text_width(s[:i], style)
		if local_x < (prev_w + w) / 2 do return prev_i
		prev_w, prev_i = w, i
	}
	return len(s)
}

// Clickable text: wraps `text` in a hit-testable element (raw clay text has no
// id) and reports a double-click on it. `id` must be unique per instance.
text_clickable :: proc(
	id: string,
	label: string,
	style: Text_Style,
	color: clay.Color,
	input: ^api.Input,
	index: u32 = 0,
) -> (
	double_clicked: bool,
) {
	eid := clay.ID(id, index)
	hovered := clay.PointerOver(eid)
	if hovered {
		input.cursor = .Pointer
		if input.left_released {
			double_clicked = register_click(eid.id, input.time)
		}
	}
	if clay.UI(eid)({layout = {sizing = {clay.SizingFit(), clay.SizingFit()}}}) {
		text(label, style, color)
	}
	return
}

ellipsize_text :: proc(text: string, max_width: f32, cfg: clay.TextElementConfig) -> string {
	cfg := cfg
	ss := clay.StringSlice {
		length    = c.int32_t(len(text)),
		chars     = ([^]c.char)(raw_data(text)),
		baseChars = ([^]c.char)(raw_data(text)),
	}

	if measure_text(ss, &cfg, nil).width <= max_width {
		return text
	}

	dots_str := "..."
	dots := clay.StringSlice {
		length    = 3,
		chars     = ([^]c.char)(raw_data(dots_str)),
		baseChars = ([^]c.char)(raw_data(dots_str)),
	}
	dots_width := measure_text(dots, &cfg, nil).width

	lo, hi := 0, len(text)
	for lo < hi {
		mid := (lo + hi + 1) / 2
		slice := clay.StringSlice {
			length    = c.int32_t(mid),
			chars     = ss.chars,
			baseChars = ss.baseChars,
		}
		if measure_text(slice, &cfg, nil).width + dots_width <= max_width {
			lo = mid
		} else {
			hi = mid - 1
		}
	}

	// Trim trailing spaces so they don't appear as phantom gaps before "...".
	for lo > 0 && text[lo - 1] == ' ' {
		lo -= 1
	}

	// Allocate from the temp allocator — freed at the end of each frame by
	// free_all(context.temp_allocator), so Clay's stored pointer stays valid
	// for exactly the frame it was created in.
	buf := make([]u8, lo + 4, context.temp_allocator)
	mem.copy(raw_data(buf), raw_data(text), lo)
	buf[lo] = '.'
	buf[lo + 1] = '.'
	buf[lo + 2] = '.'
	buf[lo + 3] = 0

	return string(buf[:lo + 3])
}
