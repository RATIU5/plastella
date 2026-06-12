package editor

import clay "../../vendor/clay"
import ui "../ui"
import rl "vendor:raylib"

Editor_State :: struct {
	sidebar_width:    f32,
	sidebar_resizing: bool,
}

editor_ctx: ^Editor_State

init :: proc() -> ^Editor_State {
	editor_ctx = new(Editor_State)
	editor_ctx^ = {
		sidebar_width    = 250,
		sidebar_resizing = false,
	}
	return editor_ctx
}


update :: proc() {
	sidebar_update()
}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)
	clay.SetLayoutDimensions({cast(f32)rl.GetScreenWidth(), cast(f32)rl.GetScreenHeight()})
	clay.BeginLayout()

	sidebar_draw()

	commands := clay.EndLayout(rl.GetFrameTime())
	ui.clay_render(&commands)
	rl.EndDrawing()
}

reload :: proc(ctx: rawptr) {
	editor_ctx = (^Editor_State)(ctx)
}
