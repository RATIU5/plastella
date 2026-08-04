package ui

import "../../vendor/clay"
import "../assets"
import "../gfx"
import "base:intrinsics"

Tab :: struct {
	id:       string,
	label:    string,
	icon:     Maybe(assets.Ui_Icons),
	disabled: bool,
}

Tab_Bar_Style :: struct {
	padding:      clay.Padding,
	gap:          u16,
	bg_color:     clay.Color,
	border_width: clay.BorderWidth,
	border_color: clay.Color,
	radius:       clay.CornerRadius,
	button:       BUTTON, // which button style the pills use
}

TAB_BAR :: enum u8 {
	DEFAULT,
}

tab_bar_styles := [TAB_BAR]Tab_Bar_Style {
	.DEFAULT = {
		padding = {3, 3, 3, 3},
		gap = 3,
		bg_color = gfx.COLOR_GREY_760,
		border_width = {1, 1, 1, 1, 0},
		border_color = gfx.COLOR_GREY_710,
		radius = {8, 8, 8, 8},
		button = .SEG_CTRL_TEXT,
	},
}

segmented_control :: proc(
	ctx: ^Ctx,
	id: string,
	active: $T,
	tabs: [T]Tab,
	theme: TAB_BAR = .DEFAULT,
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
			icon_id, has_icon := item.icon.?
			options: Button_Options
			if sel do options += {.SELECTED}
			if item.disabled do options += {.DISABLED}

			if btn, open := button(ctx, item.id, options)(st.button); open {
				if has_icon {
					assert(item.label == "")
					icon_h := f32(assets.text_styles[btn.font].size)
					icon(ctx, item.id, icon_id, icon_h, btn.fg)
				} else {
					assert(item.label != "")
					text(ctx.frame.assets, item.label, btn.font, btn.fg, .Center, .None)
				}

				if btn.clicked && !item.disabled do result = tab
			}
		}
	}

	return result
}
