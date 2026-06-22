package ui

import clay "../../vendor/clay"
import io "../io"
import render "../render"
import textures "../render/textures"
import "core:strings"

Button_State :: enum u8 {
	Normal,
	Hover,
	Active,
	Selected,
	Selected_Hover,
	Selected_Active,
	Disabled,
}

Button_Style :: struct {
	font:         render.TEXT,
	padding:      clay.Padding,
	border_width: clay.BorderWidth,
	border_color: [Button_State]clay.Color,
	bg_color:     [Button_State]clay.Color,
	fg_color:     [Button_State]clay.Color,
	radius:       clay.CornerRadius,
}

BUTTON :: enum u8 {
	SIDEBAR_TAB,
}

button_styles := [BUTTON]Button_Style {
	.SIDEBAR_TAB = {
		font = .UI_REG_14,
		padding = {top = 5, left = 5, right = 5, bottom = 5},
		bg_color = {
			.Normal = TRANSPARENT,
			.Hover = GREY_35,
			.Active = GREY_28,
			.Selected = TRANSPARENT,
			.Selected_Hover = GREY_35,
			.Selected_Active = GREY_28,
			.Disabled = TRANSPARENT,
		},
		fg_color = {
			.Normal = GREY_140,
			.Hover = GREY_180,
			.Active = GREY_160,
			.Selected = ACCENT,
			.Selected_Hover = ACCENT,
			.Selected_Active = ACCENT,
			.Disabled = GREY_90,
		},
		radius = {topLeft = 4, topRight = 4, bottomLeft = 4, bottomRight = 4},
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
) {
	hover := !disabled && render.pointer_over(id)
	active := !disabled && render.active_over(id)

	if hover do io.set_cursor(.POINTING_HAND)

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
}

@(private = "file")
button_icon :: proc(
	id: string,
	icon: textures.UI_ICONS,
	theme: BUTTON,
	sizing: Sizing = .FIT,
	disabled := false,
	selected := false,
) {
	hover := !disabled && render.pointer_over(id)
	active := !disabled && render.active_over(id)

	if hover do io.set_cursor(.POINTING_HAND)

	st := btn_color_state(active, hover, selected, disabled)
	style := button_styles[theme]
	text_style := render.text_styles[style.font]
	fg := style.fg_color[st]
	bg := style.bg_color[st]
	br := style.border_color[st]

	icon_inst := textures.ui_icon(icon)

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
			backgroundColor = fg,
		},
		) {}
	}
}

@(private = "file")
btn_color_state :: proc(active, hover, selected, disabled: bool) -> Button_State {
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
