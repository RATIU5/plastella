package layout

import clay "../../vendor/clay"
import rl "vendor:raylib"

Font :: struct {
	fontId: u16,
	font:   rl.Font,
}

Layout_State :: struct {
	fonts: [dynamic]Font,
}

@(private)
state: ^Layout_State

init_layout :: proc() -> bool {
	clay.SetMeasureTextFunction(measure_text, nil)
	clay_ctx, clay_mem, ok := init_clay({f32(rl.GetScreenWidth()), f32(rl.GetScreenHeight())})
	if !ok {
		return false
	}
	defer free(clay_mem)


	state = new(Layout_State)

	return true
}

measure_text :: proc "c" (
	text: clay.StringSlice,
	cfg: ^clay.TextElementConfig,
	ud: rawptr,
) -> clay.Dimensions {
	if state == nil || int(cfg.fontId) >= len(state.fonts) do return {}


	font := state.fonts[cfg.fontId].font
	if font.baseSize == 0 || font.glyphCount == 0 do return {}

	line_width: f32
	rune_count: int
	text_str := string(text.chars[:text.length])

	for l in text_str {
		rune_count += 1
		glyph_idx := rl.GetGlyphIndex(font, l)
		glyph := font.glyphs[glyph_idx]
		if glyph.advanceX != 0 {
			line_width += f32(glyph.advanceX)
		} else {
			line_width += font.recs[glyph_idx].width + f32(glyph.offsetX)
		}
	}

	scale := f32(cfg.fontSize) / f32(font.baseSize)
	height := cfg.lineHeight != 0 ? f32(cfg.lineHeight) : f32(cfg.fontSize)
	spacing_total := f32(cfg.letterSpacing) * f32(max(rune_count - 1, 0))

	return {line_width * scale + spacing_total, height}
}
