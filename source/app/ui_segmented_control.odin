package app

import "../../vendor/clay"
import "base:intrinsics"

Tab :: struct {
	id:       string,
	// Label or icon, never both.
	content:  union {
		string,
		Ui_Icons,
	},
	disabled: bool,
}

Tab_Bar_Style :: struct {
	padding:      clay.Padding,
	gap:          u16,
	bg_color:     clay.Color,
	border_width: clay.BorderWidth,
	border_color: clay.Color,
	radius:       clay.CornerRadius,
	button:       Button_Theme, // style for the pills
}

Tab_Bar_Theme :: enum u8 {
	Default,
}

@(rodata)
tab_bar_styles := [Tab_Bar_Theme]Tab_Bar_Style {
	.Default = {
		padding = {3, 3, 3, 3},
		gap = 3,
		bg_color = COLOR_GREY_760,
		border_width = {1, 1, 1, 1, 0},
		border_color = COLOR_GREY_710,
		radius = {8, 8, 8, 8},
		button = .Seg_Ctrl_Text,
	},
}

// Parametric over the enum so this UI file does not reach up into editor types.
segmented_control :: proc(
	ctx: ^Ctx,
	id: string,
	active: $T,
	tabs: [T]Tab,
	theme: Tab_Bar_Theme = .Default,
	direction: clay.LayoutDirection = .LeftToRight,
) -> T where intrinsics.type_is_enum(T) {
	st := tab_bar_styles[theme]
	result := active

	if clay.UI(clay.ID(id))(
	{
		layout = {
			layoutDirection = direction,
			childGap = st.gap,
			padding = st.padding,
			childAlignment = {x = .Left, y = .Center},
		},
		backgroundColor = st.bg_color,
		border = {width = st.border_width, color = st.border_color},
		cornerRadius = st.radius,
	},
	) {
		for tab in T {
			item := tabs[tab]
			sel := tab == active
			options: Button_Options
			if sel do options += {.SELECTED}
			if item.disabled do options += {.DISABLED}

			if btn, open := button(ctx, item.id, st.button, options); open {
				switch c in item.content {
				case string:
					text(ctx.frame.assets, c, btn.font, btn.fg, .Center, .None)
				case Ui_Icons:
					icon_h := f32(text_styles[btn.font].size)
					icon(ctx, item.id, c, icon_h, btn.fg)
				}

				if btn.clicked && !item.disabled do result = tab
			}
		}
	}

	return result
}
