package ui

Text_Style :: enum {
	REG_14,
	BLD_14,
	REG_20,
}

text_styles := [Text_Style]Font_Style {
	.REG_14 = {size = 14, id = FONT.BODY_REG_14, line_height = 14, letter_spacing = 0},
	.BLD_14 = {size = 14, id = FONT.BODY_BLD_14, line_height = 14, letter_spacing = 0},
	.REG_20 = {size = 20, id = FONT.BODY_REG_20, line_height = 20, letter_spacing = 0},
}
