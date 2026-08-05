package app

import "../../vendor/clay"
import "../platform"

Button_Style :: struct {
	font:         Text,
	padding:      clay.Padding,
	border_width: clay.BorderWidth,
	border_color: [Color_State]clay.Color,
	bg_color:     [Color_State]clay.Color,
	fg_color:     [Color_State]clay.Color,
	radius:       clay.CornerRadius,
	child_align:  clay.ChildAlignment,
	child_gap:    u16,
	sizing:       Sizing,
}

Button_Theme :: enum u8 {
	Default,
	Wide_Action,
	Seg_Ctrl_Text,
}

@(rodata)
button_styles := [Button_Theme]Button_Style {
	.Default = {
		font = .UI_REG_13,
		padding = {12, 12, 6, 6},
		bg_color = {
			.Normal = COLOR_TRANSPARENT,
			.Hover = COLOR_GREY_805,
			.Active = COLOR_GREY_850,
			.Engaged = COLOR_TRANSPARENT,
			.Engaged_Hover = COLOR_GREY_805,
			.Engaged_Active = COLOR_GREY_850,
			.Focus = COLOR_GREY_805,
			.Focus_Hover = COLOR_GREY_805,
			.Focus_Active = COLOR_GREY_850,
			.Disabled = COLOR_TRANSPARENT,
		},
		fg_color = {
			.Normal = COLOR_GREY_340,
			.Hover = COLOR_GREY_290,
			.Active = COLOR_GREY_290,
			.Engaged = COLOR_ACCENT,
			.Engaged_Hover = COLOR_ACCENT,
			.Engaged_Active = COLOR_ACCENT,
			.Focus = COLOR_GREY_240,
			.Focus_Hover = COLOR_GREY_240,
			.Focus_Active = COLOR_GREY_240,
			.Disabled = COLOR_GREY_605,
		},
		radius = {5, 5, 5, 5},
		child_align = {.Center, .Center},
		child_gap = 8,
		sizing = .Fit,
	},
	.Wide_Action = {
		font = .UI_REG_13,
		padding = {10, 10, 6, 6},
		bg_color = {
			.Normal = COLOR_TRANSPARENT,
			.Hover = COLOR_GREY_805,
			.Active = COLOR_GREY_850,
			.Engaged = COLOR_TRANSPARENT,
			.Engaged_Hover = COLOR_GREY_805,
			.Engaged_Active = COLOR_GREY_850,
			.Focus = COLOR_GREY_805,
			.Focus_Hover = COLOR_GREY_805,
			.Focus_Active = COLOR_GREY_850,
			.Disabled = COLOR_TRANSPARENT,
		},
		fg_color = {
			.Normal = COLOR_GREY_340,
			.Hover = COLOR_GREY_290,
			.Active = COLOR_GREY_290,
			.Engaged = COLOR_ACCENT,
			.Engaged_Hover = COLOR_ACCENT,
			.Engaged_Active = COLOR_ACCENT,
			.Focus = COLOR_GREY_240,
			.Focus_Hover = COLOR_GREY_240,
			.Focus_Active = COLOR_GREY_240,
			.Disabled = COLOR_GREY_605,
		},
		radius = {5, 5, 5, 5},
		child_align = {.Left, .Center},
		child_gap = 8,
		sizing = .Grow,
	},
	.Seg_Ctrl_Text = {
		font = .UI_REG_13,
		padding = {9, 9, 5, 5},
		bg_color = {
			.Normal = COLOR_TRANSPARENT,
			.Hover = COLOR_GREY_740,
			.Active = COLOR_GREY_740,
			.Engaged = COLOR_ACCENT,
			.Engaged_Hover = COLOR_ACCENT,
			.Engaged_Active = COLOR_ACCENT,
			.Focus = COLOR_GREY_805,
			.Focus_Hover = COLOR_GREY_805,
			.Focus_Active = COLOR_GREY_850,
			.Disabled = COLOR_TRANSPARENT,
		},
		fg_color = {
			.Normal = COLOR_GREY_240,
			.Hover = COLOR_GREY_150,
			.Active = COLOR_GREY_150,
			.Engaged = COLOR_GREY_30,
			.Engaged_Hover = COLOR_GREY_30,
			.Engaged_Active = COLOR_GREY_30,
			.Focus = COLOR_GREY_240,
			.Focus_Hover = COLOR_GREY_240,
			.Focus_Active = COLOR_GREY_240,
			.Disabled = COLOR_GREY_500,
		},
		radius = {5, 5, 5, 5},
		child_align = {.Center, .Center},
		child_gap = 8,
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
	font:    Text,
	fg:      clay.Color,
}

// theme is a direct parameter, not a curried second call: there is exactly
// one call-site shape in the codebase, so the closure/global-state protocol
// (ODIN_STYLE.md 3.2) bought nothing. Children are drawn in the caller's
// `if btn, open := button(...); open { ... }` block; button_end closes the
// element when that block's scope exits.
@(deferred_none = button_end)
button :: proc(
	ctx: ^Ctx,
	id: string,
	theme: Button_Theme,
	options: Button_Options = {},
) -> (
	Button_State,
	bool,
) {
	disabled := .DISABLED in options
	selected := .SELECTED in options
	hover := !disabled && pointer_over(id)
	active := !disabled && active_over(ctx.frame, id)
	register_focusable(ctx, id)
	focus := ctx.ui.focused == id

	if hover do ctx.frame.cursor = .Pointer

	is_clicked := !disabled && clicked(ctx.frame, id)
	if !disabled &&
	   focus &&
	   (platform.key_pressed(ctx.frame.input, .RETURN) ||
			   platform.key_pressed(ctx.frame.input, .SPACE)) {
		is_clicked = true
	}

	st := color_state(active, hover, selected, focus, disabled)
	style := button_styles[theme]

	clay._OpenElementWithId(clay.ID(id))
	clay.ConfigureOpenElement(
		{
			layout = {
				padding = style.padding,
				childAlignment = style.child_align,
				childGap = style.child_gap,
				sizing = sizing_to_clay(style.sizing),
			},
			border = {width = style.border_width, color = style.border_color[st]},
			backgroundColor = style.bg_color[st],
			cornerRadius = style.radius,
		},
	)

	return {clicked = is_clicked, font = style.font, fg = style.fg_color[st]}, true
}

@(private = "file")
button_end :: proc() {
	clay._CloseElement()
}
