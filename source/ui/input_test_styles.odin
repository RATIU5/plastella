package ui

PRIMARY_INPUT_TEXT :: Input_Text_Style {
	bg = {.Normal = GREY_30, .Hover = GREY_35, .Focus = GREY_35, .Disabled = GREY_24},
	fg = {.Normal = GREY_160, .Hover = GREY_180, .Focus = GREY_218, .Disabled = GREY_90},
	border = {.Normal = GREY_50, .Hover = GREY_57, .Focus = GREY_90, .Disabled = TRANSPARENT},
	placeholder = GREY_75,
	border_width = {left = 1, right = 1, top = 1, bottom = 1},
	state_type = .Base,
	padding = {left = 10, right = 10, top = 8, bottom = 8},
	radius = {topLeft = 0.5, topRight = 0.5, bottomLeft = 0.5, bottomRight = 0.5},
	font = .BODY_REG_16,
	font_size = 16,
}
