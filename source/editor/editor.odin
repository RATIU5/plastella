package editor

import clay "../../vendor/clay"
import gfx "../gfx"

@(require_results)
editor_init :: proc() -> bool {
	return true
}

editor_shutdown :: proc() {

}

editor_frame :: proc(frame: ^gfx.Frame) {
	if clay.UI(clay.ID("editor"))(
	{
		layout = {
			layoutDirection = .TopToBottom,
			sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
		},
	},
	) {
		toolbar_frame(frame)
	}
}
