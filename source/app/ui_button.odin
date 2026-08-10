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
	Icon,
	Wide_Action,
	Seg_Ctrl_Text,
	Status_Error,
}

@(rodata)
button_styles := [Button_Theme]Button_Style {
	.Icon = {
		font = .UI_REG_12,
		padding = {7, 7, 7, 7},
		bg_color = {
			.Normal = COLOR_GREY_740,
			.Hover = COLOR_GREY_710,
			.Active = COLOR_ACCENT,
			.Engaged = COLOR_ACCENT,
			.Engaged_Hover = COLOR_ACCENT,
			.Engaged_Active = COLOR_ACCENT,
			.Focus = COLOR_ACCENT,
			.Focus_Hover = COLOR_ACCENT,
			.Focus_Active = COLOR_ACCENT,
			.Disabled = COLOR_GREY_805,
		},
		fg_color = {
			.Normal = COLOR_GREY_150,
			.Hover = COLOR_GREY_150,
			.Active = COLOR_GREY_150,
			.Engaged = COLOR_GREY_150,
			.Engaged_Hover = COLOR_GREY_150,
			.Engaged_Active = COLOR_GREY_150,
			.Focus = COLOR_GREY_150,
			.Focus_Hover = COLOR_GREY_150,
			.Focus_Active = COLOR_GREY_150,
			.Disabled = COLOR_GREY_500,
		},
		border_color = {
			.Normal = COLOR_TRANSPARENT,
			.Hover = COLOR_TRANSPARENT,
			.Active = COLOR_TRANSPARENT,
			.Engaged = COLOR_TRANSPARENT,
			.Engaged_Hover = COLOR_TRANSPARENT,
			.Engaged_Active = COLOR_TRANSPARENT,
			.Focus = COLOR_TRANSPARENT,
			.Focus_Hover = COLOR_TRANSPARENT,
			.Focus_Active = COLOR_TRANSPARENT,
			.Disabled = COLOR_TRANSPARENT,
		},
		border_width = {1, 1, 1, 1, 0},
		radius = {5, 5, 5, 5},
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
	.Status_Error = {
		font = .UI_REG_12,
		padding = {4, 4, 4, 4},
		bg_color = {
			.Normal = COLOR_ERROR_760,
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
			.Normal = COLOR_ERROR_150,
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
		sizing = .Grow,
	},
}

Button_Opts :: struct {
	theme:    Button_Theme,
	disabled: bool,
	// Only for buttons that stay picked, like a segmented control tab.
	selected: bool,
	// nil rounds every corner and draws every edge; set them to sit flush with a
	// neighbour.
	corners:  Maybe(Corners),
	borders:  Maybe(Edges),
}

Button_State :: struct {
	clicked: bool,
	font:    Text,
	fg:      clay.Color,
}

// Label-only button: returns whether it was clicked this frame.
button :: proc(ctx: ^Ctx, id: string, label: string, opts := Button_Opts{}) -> bool {
	btn, _ := button_box(ctx, id, opts)
	text(ctx.frame.assets, label, btn.font, btn.fg, .Center, .None)
	return btn.clicked
}

// Custom children go in the caller's `if btn, open := button_box(...); open { ... }`
// block; button_end closes the element when that scope exits.
@(deferred_none = button_end)
button_box :: proc(ctx: ^Ctx, id: string, opts := Button_Opts{}) -> (Button_State, bool) {
	disabled := opts.disabled
	selected := opts.selected
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
	style := button_styles[opts.theme]

	clay._OpenElementWithId(clay.ID(id))
	clay.ConfigureOpenElement(
		{
			layout = {
				padding = style.padding,
				childAlignment = style.child_align,
				childGap = style.child_gap,
				sizing = sizing_to_clay(style.sizing),
			},
			border = {
				width = border_width_mask(style.border_width, opts.borders),
				color = style.border_color[st],
			},
			backgroundColor = style.bg_color[st],
			cornerRadius = corner_radius_mask(style.radius, opts.corners),
		},
	)

	return {clicked = is_clicked, font = style.font, fg = style.fg_color[st]}, true
}

@(private = "file")
button_end :: proc() {
	clay._CloseElement()
}
