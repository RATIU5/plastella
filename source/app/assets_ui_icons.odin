package app

import "core:c"
import sdl "vendor:sdl3"

ICON_CELL :: 128
ICON_COLS :: 8

Ui_Icons :: enum u16 {
	Project      = 0,
	Map          = 1,
	Tilesets     = 2,
	Sprites      = 3,
	Level_Editor = 4,
	Settings     = 5,
	Close        = 6,
	Add          = 7,
}

// Every icon needs an atlas slot.
#assert(len(Ui_Icons) <= ICON_COLS * ICON_COLS)

// Lives on Assets, not a package global, so a reload cannot zero it.
load_ui_icons :: proc(a: ^Assets, texture: ^sdl.Texture) {
	assert(a != nil)
	assert(texture != nil)
	for id in Ui_Icons {
		col, row := c.int(id) % ICON_COLS, c.int(id) / ICON_COLS
		a.ui_icons[id] = {
			tex  = texture,
			crop = {col * ICON_CELL, row * ICON_CELL, ICON_CELL, ICON_CELL},
			tint = [4]f32{255, 255, 255, 255},
		}
	}
}

// Copy, so callers can tint without touching shared state.
@(require_results)
ui_icon :: proc(a: ^Assets, id: Ui_Icons) -> Texture_Slice {
	return a.ui_icons[id]
}
