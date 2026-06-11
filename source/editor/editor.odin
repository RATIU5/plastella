package editor

import clay "../../vendor/clay"
import ui "../ui"
import rl "vendor:raylib"

init :: proc() {

}

update :: proc() {

}

draw :: proc() {
	rl.BeginDrawing()
	rl.ClearBackground(rl.BLACK)

	if clay.UI(clay.ID("HelloText"))(
	{
		layout = {
			sizing = {
				width = clay.SizingGrow(),
				height = clay.SizingFit({min = cast(f32)rl.GetScreenHeight() - 70}),
			},
			childAlignment = {y = .Center},
			padding = {left = 50, right = 50},
		},
	},
	) {
		clay.Text(
			"Hello, World",
			{
				fontSize = 14,
				fontId = u16(ui.FONT.BODY_REG_14),
				textColor = ui.rl_color_to_clay_color(rl.WHITE),
			},
		)
	}


	rl.EndDrawing()
}
