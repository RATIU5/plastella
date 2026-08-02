package gfx

import "../../vendor/clay"
import "../assets"
import "core:c"
import "core:fmt"
import "core:math"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"


text :: proc(
	asts: ^assets.Assets,
	str: string,
	style: assets.Text,
	color: clay.Color,
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

// Returns str unchanged if it already fits max_w, or truncated copy (...)
// Truncated result asliases ccontext.temp_allocator storage; clone it before
// current temp scope is freed if it must outlive the frame.
@(require_results)
ellipsize_text :: proc(
	str: string,
	style: assets.Text,
	max_w: f32,
	asts: ^assets.Assets,
) -> string {
	if text_width(str, style, asts) <= max_w do return str

	dots := "..."
	dots_w := text_width(dots, style, asts)
	if dots_w >= max_w do return dots

	// Fonts are logical size * device scale; budget must be converted to physical pixels
	// before it reaches `ttf`; floor as rounding up can overflow the budget by a pixel.
	budget_px := c.int(math.floor((max_w - dots_w) * asts.scale))

	measured_w: c.int
	fit_bytes: c.size_t
	ok := ttf.MeasureString(
		asts.fonts[style],
		cstring(raw_data(str)),
		c.size_t(len(str)),
		budget_px,
		&measured_w,
		&fit_bytes,
	)
	if !ok {
		fmt.eprintfln("[text] MeasureString failed: %s", sdl.GetError())
		return str
	}

	cut := int(fit_bytes)
	assert(cut >= 0)
	assert(cut <= len(str))

	for cut > 0 && str[cut - 1] == ' ' do cut -= 1 // no phantom gap before "..."
	if cut == 0 do return dots

	buf := make([]u8, cut + len(dots), context.temp_allocator)
	copy(buf, str[:cut])
	copy(buf[cut:], dots)
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
