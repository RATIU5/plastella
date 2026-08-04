package ui

import "../../vendor/clay"
import "../assets"
import "../gfx"
import "../platform"

Button_Style :: struct {
	font:         assets.Text,
	padding:      clay.Padding,
	border_width: clay.BorderWidth,
	border_color: [gfx.Color_State]clay.Color,
	bg_color:     [gfx.Color_State]clay.Color,
	fg_color:     [gfx.Color_State]clay.Color,
	radius:       clay.CornerRadius,
	child_align:  clay.ChildAlignment,
	sizing:       Sizing,
}

BUTTON :: enum u8 {
	DEFAULT,
	WIDE_ACTION,
	SEG_CTRL_TEXT,
}

button_styles := [BUTTON]Button_Style {
	.DEFAULT = {
		font = .UI_REG_13,
		padding = {12, 12, 6, 6},
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
		child_align = {.Center, .Center},
		sizing = .Fit,
	},
	.WIDE_ACTION = {
		font = .UI_REG_13,
		padding = {12, 12, 6, 6},
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
		child_align = {.Left, .Center},
		sizing = .Grow,
	},
	.SEG_CTRL_TEXT = {
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
		child_align = {.Center, .Center},
		sizing = .Fit,
	},
}

Button_Option :: enum u8 {
	DISABLED,
	SELECTED,
}

Button_Options :: bit_set[Button_Option;u8]

Button_State :: struct {
	clicked: bool,
	font:    assets.Text,
	fg:      clay.Color,
}

@(private = "file")
Button_Pending :: struct {
	color_state:    gfx.Color_State,
	clicked:        bool,
	awaiting_style: bool,
}

@(private = "file")
button_pending: Button_Pending

@(deferred_none = button_end)
button :: proc(
	ctx: ^Ctx,
	id: string,
	options: Button_Options = {},
) -> (
	proc(theme: BUTTON) -> (Button_State, bool),
) {
	assert(!button_pending.awaiting_style, "button style must be supplied immediately")

	disabled := .DISABLED in options
	selected := .SELECTED in options
	hover := !disabled && gfx.pointer_over(id)
	active := !disabled && gfx.active_over(ctx.frame, id)
	register_focusable(ctx, id)
	focus := ctx.ui.focused == id

	if hover do ctx.frame.cursor = .Pointer

	clicked := !disabled && gfx.clicked(ctx.frame, id)
	if !disabled &&
	   focus &&
	   (platform.key_pressed(ctx.frame.input, .RETURN) ||
			   platform.key_pressed(ctx.frame.input, .SPACE)) {
		clicked = true
	}

	button_pending = {
		color_state    = gfx.color_state(active, hover, selected, focus, disabled),
		clicked        = clicked,
		awaiting_style = true,
	}
	clay._OpenElementWithId(clay.ID(id))
	return button_configure
}

@(private = "file")
button_configure :: proc(theme: BUTTON) -> (Button_State, bool) {
	assert(button_pending.awaiting_style, "button has no pending style")

	pending := button_pending
	button_pending.awaiting_style = false
	style := button_styles[theme]
	st := pending.color_state

	clay.ConfigureOpenElement(
		{
			layout = {
				padding = style.padding,
				childAlignment = style.child_align,
				sizing = sizing_to_clay(style.sizing),
			},
			border = {width = style.border_width, color = style.border_color[st]},
			backgroundColor = style.bg_color[st],
			cornerRadius = style.radius,
		},
	)

	return {clicked = pending.clicked, font = style.font, fg = style.fg_color[st]}, true
}

@(private = "file")
button_end :: proc() {
	button_pending.awaiting_style = false
	clay._CloseElement()
}
