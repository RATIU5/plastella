package ui

import clay "../../vendor/clay"
import rl "vendor:raylib"

Raylib_Font :: struct {
	fontId: u16,
	font:   rl.Font,
}

clay_color_to_rl_color :: proc(color: clay.Color) -> rl.Color {
	return {u8(color.r), u8(color.g), u8(color.b), u8(color.a)}
}

rl_color_to_clay_color :: proc(color: rl.Color) -> clay.Color {
	return {f32(color.r), f32(color.g), f32(color.b), f32(color.a)}
}

raylib_fonts := [dynamic]Raylib_Font{}

measure_text :: measure_text_ascii


measure_text_ascii :: proc "c" (
	text: clay.StringSlice,
	config: ^clay.TextElementConfig,
	user_data: rawptr,
) -> clay.Dimensions {
	line_width: f32 = 0

	font := raylib_fonts[config.fontId].font
	text_str := string(text.chars[:text.length])

	for i in 0 ..< len(text_str) {
		glyph_index := text_str[i] - 32

		glyph := font.glyphs[glyph_index]

		if glyph.advanceX != 0 {
			line_width += f32(glyph.advanceX)
		} else {
			line_width += font.recs[glyph_index].width + f32(font.glyphs[glyph_index].offsetX)
		}
	}

	scale_factor := f32(config.fontSize) / f32(font.baseSize)

	total_spacing := f32(len(text_str)) * f32(config.letterSpacing)

	return {width = line_width * scale_factor + total_spacing, height = f32(config.fontSize)}
}
