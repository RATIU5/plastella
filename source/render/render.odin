package render

import clay "../../vendor/clay"
import io "../io"
import be "../render_backend"
import rl "vendor:raylib"

// Create Render_State for each backend type
when be.BACKEND == .Raylib {
	Render_State :: struct {
		fonts:    [FONT]rl.Font,
		textures: [TEXTURES]rl.Texture2D,
		clay_mem: [^]u8,
		clay_ctx: ^clay.Context,
	}
}

@(private)
state: ^Render_State

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
	// Process I/O for frame
	io.update_input()
	screen := io.screen_size()
	render := io.render_size()


	// Begin graphics drawing
	when be.BACKEND == .Raylib {
		draw_begin_rl(render, screen)
	}

	// Begin clay layout
	begin_layout_clay(screen, io.mouse_pos(), io.mouse_down(.LEFT))
}

frame_end :: proc() {
	commands := clay.EndLayout(io.delta_time())

	when be.BACKEND == .Raylib {
		render_clay_commands_rl(&commands)
		draw_end_rl()
	}
}

@(private = "file")
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
