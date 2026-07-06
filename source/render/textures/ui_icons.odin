package textures

import rl "vendor:raylib"

UI_ICON_PATH :: "resources/textures/ui_icons.png"
ICON_CELL :: 64
ICON_COLS :: 16

UI_ICONS :: enum u16 {
	PROJECT      = 0,
	MAP          = 1,
	TILESETS     = 2,
	SPRITES      = 3,
	LEVEL_EDITOR = 4,
	SETTINGS     = 5,
	CLOSE        = 6,
}

@(private)
ui_icons_slice: [UI_ICONS]Texture_Slice

load_ui_icons :: proc(texture: ^rl.Texture2D) {
	for id in UI_ICONS {
		col, row := int(id) % ICON_COLS, int(id) / ICON_COLS
		ui_icons_slice[id] = {
			tex  = texture,
			crop = {f32(col * ICON_CELL), f32(row * ICON_CELL), ICON_CELL, ICON_CELL},
			tint = [4]f32{255, 255, 255, 255},
		}
	}
}

ui_icon :: proc(id: UI_ICONS) -> ^Texture_Slice {
	return &ui_icons_slice[id]
}
