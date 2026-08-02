package assets

import "core:c"
import sdl "vendor:sdl3"

ICON_CELL :: 64
ICON_COLS :: 16

Ui_Icons :: enum u16 {
	Project      = 0,
	Map          = 1,
	Tilesets     = 2,
	Sprites      = 3,
	Level_Editor = 4,
	Settings     = 5,
	Close        = 6,
}

@(private)
ui_icons_slice: [Ui_Icons]Texture_Slice

load_ui_icons :: proc(texture: ^sdl.Texture) {
	for id in Ui_Icons {
		col, row := c.int(id) % ICON_COLS, c.int(id) / ICON_COLS
		ui_icons_slice[id] = {
			tex  = texture,
			crop = {col * ICON_CELL, row * ICON_CELL, ICON_CELL, ICON_CELL},
			tint = [4]f32{255, 255, 255, 255},
		}
	}
}

ui_icon :: proc(id: Ui_Icons) -> ^Texture_Slice {
	return &ui_icons_slice[id]
}
