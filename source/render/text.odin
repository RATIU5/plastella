package render

import clay "../../vendor/clay"
import "core:c"
import "core:unicode/utf8"

Text_Style :: struct {
	font:           FONT,
	size:           u16,
	line_height:    u16,
	letter_spacing: u16,
}

TEXT :: enum {
	UI_REG_14,
	UI_BLD_14,
}

text_styles := [TEXT]Text_Style {
	.UI_REG_14 = {font = .UI_REG_14, size = 14, line_height = 14},
	.UI_BLD_14 = {font = .UI_BLD_14, size = 14, line_height = 14},
}

text :: proc(
	str: string,
	style: TEXT,
	color: clay.Color,
	align := clay.TextAlignment.Left,
	wrap := clay.TextWrapMode.Words,
	ellipsize: f32 = 0,
) {
	s := text_styles[style]
	str := str
	if ellipsize > 0 do str = ellipsize_text(str, style, ellipsize)
	clay.Text(
		str,
		clay.TextElementConfig(
			{
				fontId = u16(s.font),
				fontSize = s.size,
				textColor = color,
				lineHeight = s.line_height,
				letterSpacing = s.letter_spacing,
				textAlignment = align,
				wrapMode = wrap,
			},
		),
	)
}

text_width :: proc(str: string, style: TEXT) -> f32 {
	s := text_styles[style]
	cfg := clay.TextElementConfig {
		fontId        = u16(s.font),
		fontSize      = s.size,
		letterSpacing = s.letter_spacing,
		lineHeight    = s.line_height,
	}
	slice := clay.StringSlice {
		length = i32(len(str)),
		chars  = ([^]c.char)(raw_data(str)),
	}
	return measure_text(slice, &cfg, nil).width
}

ellipsize_text :: proc(str: string, style: TEXT, max_w: f32) -> string {
	if text_width(str, style) <= max_w do return str

	dots_w := text_width("...", style)
	cut := 0
	for i := 0; i < len(str);  /**/{
		_, w := utf8.decode_rune(str[i:])
		if text_width(str[:i + w], style) + dots_w > max_w do break
		i += w
		cut = i
	}
	for cut > 0 && str[cut - 1] == ' ' do cut -= 1 // no phantom gap before "..."

	buf := make([]u8, cut + 3, context.temp_allocator) // freed by free_all(temp) each frame
	copy(buf, str[:cut])
	copy(buf[cut:], "...")
	return string(buf)
}
