package ui

import clay "../../vendor/clay"
import platform "../platform"
import render "../render"
import textures "../render/textures"
import "core:strings"

Button_Style :: struct {
	font:         render.TEXT,
	padding:      clay.Padding,
	border_width: clay.BorderWidth,
	border_color: [Color_State]clay.Color,
	bg_color:     [Color_State]clay.Color,
	fg_color:     [Color_State]clay.Color,
	radius:       clay.CornerRadius,
}

BUTTON :: enum u8 {
	SIDEBAR_TAB,
	SIDEBAR_TEXT,
}

button_styles := [BUTTON]Button_Style {
	.SIDEBAR_TAB = {
		font = .UI_ICN_18,
		padding = {top = 5, left = 5, right = 5, bottom = 5},
		bg_color = {
			.Normal = TRANSPARENT,
			.Hover = GREY_805,
			.Active = GREY_850,
			.Selected = TRANSPARENT,
			.Selected_Hover = GREY_805,
			.Selected_Active = GREY_850,
			.Disabled = TRANSPARENT,
		},
		fg_color = {
			.Normal = GREY_340,
			.Hover = GREY_290,
			.Active = GREY_290,
			.Selected = ACCENT,
			.Selected_Hover = ACCENT,
			.Selected_Active = ACCENT,
			.Disabled = GREY_605,
		},
		radius = {topLeft = 5, topRight = 5, bottomLeft = 5, bottomRight = 5},
	},
	.SIDEBAR_TEXT = {
		font = .UI_REG_14,
		padding = {top = 5, left = 10, right = 10, bottom = 5},
		bg_color = {
			.Normal = GREY_805,
			.Hover = GREY_760,
			.Active = GREY_805,
			.Selected = GREY_805,
			.Selected_Hover = GREY_760,
			.Selected_Active = GREY_805,
			.Disabled = GREY_850,
		},
		fg_color = {
			.Normal = GREY_290,
			.Hover = GREY_240,
			.Active = GREY_340,
			.Selected = GREY_290,
			.Selected_Hover = GREY_240,
			.Selected_Active = GREY_340,
			.Disabled = GREY_500,
		},
		border_color = {
			.Normal = GREY_710,
			.Hover = GREY_660,
			.Active = GREY_760,
			.Selected = GREY_290,
			.Selected_Hover = GREY_240,
			.Selected_Active = GREY_340,
			.Disabled = GREY_805,
		},
		border_width = {top = 1, left = 1, right = 1, bottom = 1},
		radius = {topLeft = 5, topRight = 5, bottomLeft = 5, bottomRight = 5},
	},
}

button :: proc {
	button_text,
	button_icon,
}

@(private = "file")
button_text :: proc(
	id: string,
	label: string,
	theme: BUTTON,
	sizing: Sizing = .FIT,
	disabled := false,
	selected := false,
) -> bool {
	hover := !disabled && render.pointer_over(id)
	active := !disabled && render.active_over(id)

	if hover do platform.set_cursor(.POINTING_HAND)

	st := btn_color_state(active, hover, selected, disabled)
	style := button_styles[theme]
	fg := style.fg_color[st]
	bg := style.bg_color[st]
	br := style.border_color[st]

	if clay.UI(clay.ID(id))(
	{
		layout = {
			padding = style.padding,
			childAlignment = {x = .Center, y = .Center},
			sizing = sizing_to_clay(sizing),
		},
		border = {width = style.border_width, color = br},
		backgroundColor = bg,
		cornerRadius = style.radius,
	},
	) {
		render.text(label, .UI_REG_14, fg, .Center, .None)
	}

	return render.clicked(id)
}

@(private = "file")
button_icon :: proc(
	id: string,
	icon: textures.UI_ICONS,
	theme: BUTTON,
	sizing: Sizing = .FIT,
	disabled := false,
	selected := false,
) -> bool {
	hover := !disabled && render.pointer_over(id)
	active := !disabled && render.active_over(id)

	if hover do platform.set_cursor(.POINTING_HAND)

	st := btn_color_state(active, hover, selected, disabled)
	style := button_styles[theme]
	text_style := render.text_styles[style.font]
	fg := style.fg_color[st]
	bg := style.bg_color[st]
	br := style.border_color[st]

	icon_inst := textures.ui_icon(icon)
	icon_inst.tint = fg

	if clay.UI(clay.ID(id))(
	{
		layout = {
			padding = style.padding,
			childAlignment = {x = .Center, y = .Center},
			sizing = sizing_to_clay(sizing),
		},
		border = {width = style.border_width, color = br},
		backgroundColor = bg,
		cornerRadius = style.radius,
	},
	) {
		icon_id := strings.concatenate([]string{id, "_icon"}, context.temp_allocator)
		icon_h := f32(text_style.size)
		icon_w := icon_h * (icon_inst.crop.width / icon_inst.crop.height)

		if clay.UI(clay.ID(icon_id))(
		{
			layout = {
				sizing = {width = clay.SizingFixed(icon_w), height = clay.SizingFixed(icon_h)},
			},
			image = {imageData = rawptr(icon_inst)},
			aspectRatio = {icon_inst.crop.width / icon_inst.crop.height},
		},
		) {}
	}

	return render.clicked(id)
}

@(private = "file")
btn_color_state :: proc(active, hover, selected, disabled: bool) -> Color_State {
	switch {
	case disabled:
		return .Disabled
	case selected && active:
		return .Selected_Active
	case selected && hover:
		return .Selected_Hover
	case active:
		return .Active
	case selected:
		return .Selected
	case hover:
		return .Hover
	case:
		return .Normal
	}
}
