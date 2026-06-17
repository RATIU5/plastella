package ui

Text_Style :: enum {
	REG_14,
	BLD_14,
}

text_styles := [Text_Style]Font_Style {
	.REG_14 = {size = 14, id = u16(FONT.BODY_REG_14), line_height = 10, letter_spacing = 0},
	.BLD_14 = {size = 14, id = u16(FONT.BODY_BLD_14), line_height = 10, letter_spacing = 0},
}
