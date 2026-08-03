package ui

import "../../vendor/clay"
import "../assets"
import "../gfx"
import "../platform"
import "core:strings"

Button_Style :: struct {
	font:         assets.Text,
	padding:      clay.Padding,
	border_width: clay.BorderWidth,
	border_color: [gfx.Color_State]clay.Color,
	bg_color:     [gfx.Color_State]clay.Color,
	fg_color:     [gfx.Color_State]clay.Color,
	radius:       clay.CornerRadius,
}

BUTTON :: enum u8 {
	DEFAULT,
	TAB_TEXT,
}

button_styles := [BUTTON]Button_Style {
	.DEFAULT = {
		font = .UI_REG_16,
		padding = {6, 6, 6, 6},
		bg_color = {
			.Normal = gfx.COLOR_TRANSPARENT,
			.Hover = gfx.COLOR_GREY_805,
			.Active = gfx.COLOR_GREY_850,
			.Engaged = gfx.COLOR_TRANSPARENT,
			.Engaged_Hover = gfx.COLOR_GREY_805,
			.Engaged_Active = gfx.COLOR_GREY_850,
			.Focus = gfx.COLOR_GREY_805,
			.Focus_Hover = gfx.COLOR_GREY_805,
			.Focus_Active = gfx.COLOR_GREY_850,
			.Disabled = gfx.COLOR_TRANSPARENT,
		},
		fg_color = {
			.Normal = gfx.COLOR_GREY_340,
			.Hover = gfx.COLOR_GREY_290,
			.Active = gfx.COLOR_GREY_290,
			.Engaged = gfx.COLOR_ACCENT,
			.Engaged_Hover = gfx.COLOR_ACCENT,
			.Engaged_Active = gfx.COLOR_ACCENT,
			.Focus = gfx.COLOR_GREY_240,
			.Focus_Hover = gfx.COLOR_GREY_240,
			.Focus_Active = gfx.COLOR_GREY_240,
			.Disabled = gfx.COLOR_GREY_605,
		},
		radius = {5, 5, 5, 5},
	},
	.TAB_TEXT = {
		font = .UI_REG_13,
		padding = {9, 9, 5, 5},
		bg_color = {
			.Normal = gfx.COLOR_TRANSPARENT,
			.Hover = gfx.COLOR_GREY_740,
			.Active = gfx.COLOR_GREY_740,
			.Engaged = gfx.COLOR_ACCENT,
			.Engaged_Hover = gfx.COLOR_ACCENT,
			.Engaged_Active = gfx.COLOR_ACCENT,
			.Focus = gfx.COLOR_GREY_805,
			.Focus_Hover = gfx.COLOR_GREY_805,
			.Focus_Active = gfx.COLOR_GREY_850,
			.Disabled = gfx.COLOR_TRANSPARENT,
		},
		fg_color = {
			.Normal = gfx.COLOR_GREY_240,
			.Hover = gfx.COLOR_GREY_150,
			.Active = gfx.COLOR_GREY_150,
			.Engaged = gfx.COLOR_GREY_30,
			.Engaged_Hover = gfx.COLOR_GREY_30,
			.Engaged_Active = gfx.COLOR_GREY_30,
			.Focus = gfx.COLOR_GREY_240,
			.Focus_Hover = gfx.COLOR_GREY_240,
			.Focus_Active = gfx.COLOR_GREY_240,
			.Disabled = gfx.COLOR_GREY_500,
		},
		radius = {5, 5, 5, 5},
	},
}

button :: proc {
	button_text,
	button_icon,
}

@(private = "file")
button_text :: proc(
	ctx: ^Ctx,
	id: string,
	label: string,
	theme: BUTTON,
	sizing: Sizing = .FIT,
	disabled := false,
	selected := false,
) -> bool {
	hover := !disabled && gfx.pointer_over(id)
	active := !disabled && gfx.active_over(ctx.frame, id)
	register_focusable(ctx, id)
	focus := ctx.ui.focused == id

	if hover do ctx.frame.cursor = .Pointer

	st := gfx.color_state(active, hover, selected, focus, disabled)
	style := button_styles[theme]
	fg := style.fg_color[st]
	bg := style.bg_color[st]
	br := style.border_color[st]

	clicked := gfx.clicked(ctx.frame, id)
	if focus &&
	   (platform.key_pressed(ctx.frame.input, .RETURN) ||
			   platform.key_pressed(ctx.frame.input, .SPACE)) {
		clicked = true
	}

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
		gfx.text(ctx.frame.assets, label, style.font, fg, .Center, .None)
	}

	return clicked
}

@(private = "file")
button_icon :: proc(
	ctx: ^Ctx,
	id: string,
	icon: assets.Ui_Icons,
	theme: BUTTON,
	sizing: Sizing = .FIT,
	disabled := false,
	selected := false,
) -> bool {
	hover := !disabled && gfx.pointer_over(id)
	active := !disabled && gfx.active_over(ctx.frame, id)
	register_focusable(ctx, id)
	focus := ctx.ui.focused == id

	if hover do ctx.frame.cursor = .Pointer

	st := gfx.color_state(active, hover, selected, focus, disabled)
	style := button_styles[theme]
	text_style := assets.text_styles[style.font]
	fg := style.fg_color[st]
	bg := style.bg_color[st]
	br := style.border_color[st]

	// Clay stores imageData as rawptr, so the instance must outlive this scope;
	// heap-into-temp gives it a frame lifetime with no ownership question.
	icon_inst := new_clone(assets.ui_icon(ctx.frame.assets, icon), context.temp_allocator)
	icon_inst.tint = fg

	clicked := gfx.clicked(ctx.frame, id)
	if focus &&
	   (platform.key_pressed(ctx.frame.input, .RETURN) ||
			   platform.key_pressed(ctx.frame.input, .SPACE)) {
		clicked = true
	}

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
		icon_w := icon_h * (f32(icon_inst.crop.w) / f32(icon_inst.crop.h))

		if clay.UI(clay.ID(icon_id))(
		{
			layout = {
				sizing = {width = clay.SizingFixed(icon_w), height = clay.SizingFixed(icon_h)},
			},
			image = {imageData = rawptr(icon_inst)},
			aspectRatio = {f32(icon_inst.crop.w) / f32(icon_inst.crop.h)},
		},
		) {}
	}

	return clicked
}
