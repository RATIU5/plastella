package ui_old

// Each style's per-state colors are an enumerated array indexed by Button_State.
// A state's color appears exactly once, and unspecified states would be zero
// (transparent) — so every state is listed. Backgrounds that should look the
// same hovered vs. selected-and-hovered just point Selected_Hover at the hover
// value; the widget never falls back across states.

PRIMARY_BUTTON :: Button_Style {
	bg = {
		.Normal = GREY_30,
		.Hover = GREY_35,
		.Active = GREY_28,
		.Selected = GREY_46,
		.Selected_Hover = GREY_35,
		.Selected_Active = GREY_35,
		.Disabled = GREY_24,
	},
	fg = {
		.Normal = GREY_218,
		.Hover = GREY_218,
		.Active = GREY_218,
		.Selected = GREY_218,
		.Selected_Hover = GREY_218,
		.Selected_Active = GREY_218,
		.Disabled = GREY_90,
	},
	border = GREY_50,
	padding = {left = 28, right = 28, top = 6, bottom = 6},
	radius = 0.5,
	border_width = 1,
	font = .BODY_REG_14,
	font_size = 14,
	width_type = .FIT,
}

DEV_NOTICE_CLOSE_BUTTON :: Button_Style {
	bg = {
		.Normal = TRANSPARENT,
		.Hover = WARN_BG_HOVER,
		.Active = GREY_28,
		.Selected = GREY_46,
		.Selected_Hover = WARN_BG_HOVER,
		.Selected_Active = WARN_BG_HOVER,
		.Disabled = TRANSPARENT,
	},
	fg = {
		.Normal = GREY_140,
		.Hover = GREY_180,
		.Active = GREY_160,
		.Selected = GREY_140,
		.Selected_Hover = GREY_180,
		.Selected_Active = GREY_180,
		.Disabled = GREY_90,
	},
	border = TRANSPARENT,
	padding = {left = 5, right = 5, top = 5, bottom = 5},
	radius = 0.5,
	border_width = 0,
	font = .BODY_REG_14,
	font_size = 12,
	width_type = .FIT,
}

SIDEBAR_TAB_BUTTON :: Button_Style {
	bg = {
		.Normal = TRANSPARENT,
		.Hover = GREY_35,
		.Active = GREY_28,
		.Selected = TRANSPARENT,
		.Selected_Hover = GREY_35,
		.Selected_Active = GREY_28,
		.Disabled = TRANSPARENT,
	},
	fg = {
		.Normal = GREY_140,
		.Hover = GREY_180,
		.Active = GREY_160,
		.Selected = ACCENT,
		.Selected_Hover = ACCENT,
		.Selected_Active = ACCENT,
		.Disabled = GREY_90,
	},
	border = TRANSPARENT,
	padding = {left = 5, right = 5, top = 5, bottom = 5},
	radius = 0.5,
	border_width = 0,
	font = .BODY_REG_14,
	font_size = 18,
	width_type = .FIT,
}
