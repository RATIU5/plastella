package app

import "core:c"
import sdl "vendor:sdl3"

ICON_CELL :: 32
ICON_COLS :: 32

Ui_Icons :: enum u16 {
	Project          = 0,
	Map              = 1,
	Tilesets         = 2,
	Sprites          = 3,
	Level_Editor     = 4,
	Settings         = 5,
	X_Small          = 6,
	X_Large          = 7,
	Plus_Small       = 8,
	Plus_Large       = 9,
	Chev_Right_Small = 10,
	Chev_Right_Large = 11,
	Chev_Left_Small  = 12,
	Chev_Left_Large  = 13,
	Chev_Up_Small    = 14,
	Chev_Up_Large    = 15,
	Chev_Down_Small  = 16,
	Chev_Down_Large  = 17,
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
