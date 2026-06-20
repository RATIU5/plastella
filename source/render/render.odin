package render

import clay "../../vendor/clay"
import io "../io"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

Render_State :: struct {
	fonts:    [FONT]rl.Font,
	textures: [TEXS]rl.Texture2D,
	clay_mem: [^]u8,
	clay_ctx: ^clay.Context,
}

@(private)
state: ^Render_State

@(private)
measure_text :: proc "c" (
	text: clay.StringSlice,
	cfg: ^clay.TextElementConfig,
	ud: rawptr,
) -> clay.Dimensions {
	if state == nil || int(cfg.fontId) >= len(state.fonts) do return {}

	font := state.fonts[FONT(cfg.fontId)]
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

render_init :: proc() -> bool {
	clay_ctx, clay_mem, ok := init_clay(io.screen_size())
	if !ok {
		return false
	}

	state = new(Render_State)
	state.clay_mem = clay_mem
	state.clay_ctx = clay_ctx

	clay.SetMeasureTextFunction(measure_text, nil)

	load_fonts()
	load_textures()

	return true
}

render_shutdown :: proc() {
	if state == nil do return
	unload_fonts()
	unload_textures()
	free(state.clay_mem)
	free(state)
	state = nil
}


frame_begin :: proc() {
	// IO
	io.update_input()
	screen := io.screen_size()
	render := io.render_size()

	// OPENGL
	rl.BeginDrawing()
	// After display hot-plug, raylib draws at old scale. Rebuild transform deterministically.
	rlgl.Viewport(0, 0, render.x, render.y)
	rlgl.MatrixMode(rlgl.PROJECTION)
	rlgl.LoadIdentity()
	rlgl.Ortho(0, f64(screen.x), f64(screen.y), 0, 0, 1)
	rlgl.MatrixMode(rlgl.MODELVIEW)
	rlgl.LoadIdentity()

	rl.ClearBackground(rl.BLACK)

	// CLAY
	reset_clay_error()
	clay.SetLayoutDimensions({f32(screen.x), f32(screen.y)})
	clay.SetPointerState(io.mouse_pos(), io.mouse_down(.LEFT))
	clay.BeginLayout()
}
