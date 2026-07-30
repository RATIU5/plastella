package gfx

import clay "../../vendor/clay"
import assets "../assets"
import "core:c"
import "core:unicode/utf8"


text :: proc(
	str: string,
	style: assets.Text,
	color: clay.Color,
	asts: ^assets.Assets,
	align := clay.TextAlignment.Left,
	wrap := clay.TextWrapMode.Words,
	ellipsize: f32 = 0,
) {
	s := assets.text_styles[style]
	str := str
	if ellipsize > 0 do str = ellipsize_text(str, style, ellipsize, asts)
	clay.Text(
		str,
		clay.TextElementConfig(
			{
				fontId = u16(style),
				fontSize = s.size,
				lineHeight = s.line_height,
				letterSpacing = s.letter_spacing,
				textAlignment = align,
				textColor = color,
				wrapMode = wrap,
			},
		),
	)
}

ellipsize_text :: proc(
	str: string,
	style: assets.Text,
	max_w: f32,
	asts: ^assets.Assets,
) -> string {
	if text_width(str, style, asts) <= max_w do return str

	dots_w := text_width("...", style, asts)
	cut := 0
	for i := 0; i < len(str); {
		_, w := utf8.decode_rune(str[i:])
		if text_width(str[:i + w], style, asts) + dots_w > max_w do break
		i += w
		cut = i
	}
	for cut > 0 && str[cut - 1] == ' ' do cut -= 1 // no phantom gap before "..."

	buf := make([]u8, cut + 3, context.temp_allocator) // freed by free_all(temp) each frame
	copy(buf, str[:cut])
	copy(buf[cut:], "...")
	return string(buf)
}

text_width :: proc(str: string, style: assets.Text, asts: ^assets.Assets) -> f32 {
	s := assets.text_styles[style]
	cfg := clay.TextElementConfig {
		fontId        = u16(style),
		fontSize      = s.size,
		letterSpacing = s.letter_spacing,
		lineHeight    = s.line_height,
	}
	slice := clay.StringSlice {
		length = i32(len(str)),
		chars  = ([^]c.char)(raw_data(str)),
	}
	return measure_text(slice, &cfg, asts).width
}
