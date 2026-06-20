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

UI_Icon :: struct {
	tex: ^rl.Texture2D,
	src: rl.Rectangle,
}

@(private)
ui_icons: [UI_ICONS]UI_Icon

load_ui_icons :: proc(texture: ^rl.Texture2D) {
	for id in UI_ICONS {
		idx := int(id)
		col := idx % ICON_COLS
		row := idx / ICON_COLS
		ui_icons[id] = {
			tex = texture,
			src = {f32(col * ICON_CELL), f32(row * ICON_CELL), ICON_CELL, ICON_CELL},
		}
	}
}

unload_ui_icons :: proc() {
	for icon in ui_icons do free(icon.tex)
}

ui_icon :: proc(id: UI_ICONS) -> ^UI_Icon {
	return &ui_icons[id]
}
