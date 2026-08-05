package app

import "../../vendor/clay"

main_editor_frame :: proc(ctx: ^Ctx, edtr: ^Editor) {
	if clay.UI(clay.ID("main_area"))(
	{layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()}}},
	) {
		no_project(ctx, edtr)
	}
}
