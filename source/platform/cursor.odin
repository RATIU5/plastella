package platform

import "core:fmt"
import sdl "vendor:sdl3"

Cursor :: enum u8 {
	Default,
	Pointer,
	Text,
	Not_Allowed,
}

cursor_sdl_kind := [Cursor]sdl.SystemCursor {
	.Default     = .DEFAULT,
	.Pointer     = .POINTER,
	.Text        = .TEXT,
	.Not_Allowed = .NOT_ALLOWED,
}

cursor_apply :: proc(device: ^Device, cursor: Cursor) {
	if cursor == device.cursor_current do return
	ok := sdl.SetCursor(device.cursors[cursor])
	if !ok {
		fmt.eprintln("Failed to apply new cursor")
	}
	device.cursor_current = cursor
}
