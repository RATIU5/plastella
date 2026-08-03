package assets

import "../platform"
import "core:fmt"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"

Font_Face :: enum u8 {
	Body_Med,
	Body_Med_Italic,
	Body_Bold,
	Body_Bold_Italic,
}

Text_Style :: struct {
	face:           Font_Face,
	size:           u16,
	line_height:    u16,
	letter_spacing: u16,
}

Text :: enum u8 {
	UI_REG_16,
	UI_REG_14,
	UI_REG_13,
	UI_BLD_13,
	UI_REG_12,
}

@(rodata)
text_styles := [Text]Text_Style {
	.UI_REG_16 = {.Body_Med, 16, 16, 0},
	.UI_REG_14 = {.Body_Med, 14, 14, 0},
	.UI_REG_13 = {.Body_Med, 13, 13, 0},
	.UI_BLD_13 = {.Body_Bold, 13, 13, 0},
	.UI_REG_12 = {.Body_Med, 12, 12, 0},
}

@(rodata)
font_paths := [Font_Face]cstring {
	.Body_Med         = "resources/fonts/Inter-Medium.ttf",
	.Body_Med_Italic  = "resources/fonts/Inter-MediumItalic.ttf",
	.Body_Bold        = "resources/fonts/Inter-Bold.ttf",
	.Body_Bold_Italic = "resources/fonts/Inter-BoldItalic.ttf",
}

@(require_results)
load_fonts :: proc(a: ^Assets, device: ^platform.Device) -> bool {
	for style, id in text_styles {
		a.fonts[id] = ttf.OpenFont(font_paths[style.face], f32(style.size) * device.scale)
		if a.fonts[id] == nil {
			fmt.eprintfln("failed to open %s: %s", font_paths[style.face], sdl.GetError())
			unload_fonts(a)
			return false
		}
	}
	a.scale = device.scale
	return true
}

unload_fonts :: proc(a: ^Assets) {
	for font in a.fonts do if font != nil do ttf.CloseFont(font)
	a.fonts = {}
}
