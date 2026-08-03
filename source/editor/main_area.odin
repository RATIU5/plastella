package editor

import "../../vendor/clay"
import "../ui"
import "./areas"
import "./editor_types"

main_editor_frame :: proc(ctx: ^ui.Ctx, edtr: ^editor_types.Editor) {
	if clay.UI(clay.ID("main_area"))(
	{layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()}}},
	) {
		areas.no_project(ctx, edtr)
	}
}
