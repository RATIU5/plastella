package assets

import "core:fmt"
import sdl "vendor:sdl3"
import ttf "vendor:sdl3/ttf"

FONT_SIZE_BASE :: 14

Font_Type :: enum u8 {
	Body_Med,
	Body_Med_Italic,
	Body_Bold,
	Body_Bold_Italic,
}

Font_Paths :: [Font_Type]cstring {
	.Body_Med         = "resources/fonts/Inter-Medium.ttf",
	.Body_Med_Italic  = "resources/fonts/Inter-MediumItalic.ttf",
	.Body_Bold        = "resources/fonts/Inter-Bold.ttf",
	.Body_Bold_Italic = "resources/fonts/Inter-BoldItalic.ttf",
}

load_fonts :: proc(a: ^Assets) -> bool {
	#assert(len(Font_Type) <= int(max(u16)))
	for path, id in Font_Paths {
		a.fonts[id] = ttf.OpenFont(path, FONT_SIZE_BASE)
		if a.fonts[id] == nil {
			fmt.eprintfln("failed to open %s: %s", path, sdl.GetError())
			unload_fonts(a)
			return false
		}
	}
	return true
}

unload_fonts :: proc(a: ^Assets) {
	for font in a.fonts do if font != nil do ttf.CloseFont(font)
	a.fonts = {}
}
