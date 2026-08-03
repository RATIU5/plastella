package area

import "../../../vendor/clay"
import "../../ui"
import "../editor_types"

no_project :: proc(ctx: ^ui.Ctx, edtr: ^editor_types.Editor) {
	if edtr.project == nil &&
	   clay.UI(clay.ID("main_area:no_project"))(
	   {
		   layout = {
			   sizing = {width = clay.SizingGrow(), height = clay.SizingGrow()},
			   layoutDirection = .TopToBottom,
			   childAlignment = {x = .Center, y = .Center},
		   },
	   },
	   ) {
		if clay.UI(clay.ID("main_area:no_project:inner"))(
		{
			layout = {
				sizing = {width = clay.SizingPercent(0.5), height = clay.SizingPercent(0.5)},
				layoutDirection = .TopToBottom,
				childAlignment = {x = .Center, y = .Center},
				childGap = 16,
			},
		},
		) {
			ui.image(ctx, "main_area:no_project:logo", .Logo, 200)
			ui.button(ctx, "main_area:no_project:button_new", "New Project", .DEFAULT)
		}
	}
}
