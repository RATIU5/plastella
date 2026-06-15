package ui

import clay "../../vendor/clay"
import rl "vendor:raylib"

// Single 1024x1024 sheet of white-on-transparent glyphs in a uniform grid.
// White RGB + alpha coverage lets the renderer recolor each icon with a plain
// multiply tint (see the .Image case in clay_render). Source cells are 64px;
// each ICON enum value is the row-major index of its cell in the sheet.
ICON_SHEET_PATH :: "resources/icons/icon_sheet.png"
ICON_CELL :: 64
ICON_COLS :: 16

// Order MUST match the sheet's row-major cell order. Add names as you fill the
// sheet; the integer value is the cell index.
ICON :: enum u16 {
	MAP = 0,
}

Icon :: struct {
	texture: rl.Texture2D, // handle into the shared sheet
	src:     rl.Rectangle, // sub-rect of the cell within the sheet (drives aspect)
	tint:    clay.Color, // multiply color; set per-use before layout, read at render
}

// Load the sheet once and slice an Icon (shared texture handle + cell rect) for
// every ICON. Called from init_clay alongside the fonts.
load_icons :: proc() {
	state.icon_sheet = rl.LoadTexture(ICON_SHEET_PATH)
	rl.SetTextureFilter(state.icon_sheet, .BILINEAR)
	rl.GenTextureMipmaps(&state.icon_sheet)

	for id in ICON {
		idx := int(id)
		col := idx % ICON_COLS
		row := idx / ICON_COLS
		state.icons[id] = Icon {
			texture = state.icon_sheet,
			src     = {f32(col * ICON_CELL), f32(row * ICON_CELL), ICON_CELL, ICON_CELL},
		}
	}
}

// Pointer is stable for the process lifetime, so it is safe to hand to clay's
// imageData (read back in clay_render after the frame is laid out).
get_icon :: proc(id: ICON) -> ^Icon {
	return &state.icons[id]
}
