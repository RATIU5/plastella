package gfx

Color_State :: enum u8 {
	Normal,
	Hover,
	Active,
	Disabled,
	Engaged,
	Engaged_Hover,
	Engaged_Active,
	Focus,
	Focus_Hover,
	Focus_Active,
}

COLOR_TRANSPARENT :: [4]f32{0, 0, 0, 0}

COLOR_GREY_30 :: [4]f32{245, 245, 244, 255}
COLOR_GREY_65 :: [4]f32{235, 235, 235, 255}
COLOR_GREY_105 :: [4]f32{225, 225, 225, 255}
COLOR_GREY_150 :: [4]f32{211, 211, 211, 255}
COLOR_GREY_195 :: [4]f32{198, 198, 198, 255}
COLOR_GREY_240 :: [4]f32{186, 186, 186, 255}
COLOR_GREY_290 :: [4]f32{171, 170, 165, 255}
COLOR_GREY_340 :: [4]f32{156, 154, 150, 255}
COLOR_GREY_395 :: [4]f32{142, 139, 134, 255}
COLOR_GREY_445 :: [4]f32{126, 124, 118, 255}
COLOR_GREY_500 :: [4]f32{109, 109, 109, 255}
COLOR_GREY_555 :: [4]f32{97, 96, 91, 255}
COLOR_GREY_605 :: [4]f32{87, 87, 87, 255}
COLOR_GREY_660 :: [4]f32{74, 74, 74, 255}
COLOR_GREY_710 :: [4]f32{66, 66, 66, 255}
COLOR_GREY_740 :: [4]f32{56, 56, 56, 255}
COLOR_GREY_760 :: [4]f32{48, 48, 48, 255}
COLOR_GREY_805 :: [4]f32{42, 41, 39, 255}
COLOR_GREY_850 :: [4]f32{32, 32, 32, 255}
COLOR_GREY_895 :: [4]f32{18, 18, 18, 255}
COLOR_GREY_935 :: [4]f32{13, 13, 12, 255}
COLOR_GREY_970 :: [4]f32{5, 5, 5, 255}

COLOR_ACCENT :: [4]f32{49, 105, 227, 255}

opacity :: #force_inline proc "contextless" (color: [4]f32, opacity: u8 = 255) -> [4]f32 {
	return {color.r, color.g, color.b, f32(opacity)}
}

color_state :: proc(active, hover, engaged, focus, disabled: bool) -> Color_State {
	switch {
	case disabled:
		return .Disabled
	case engaged && active:
		return .Engaged_Active
	case engaged && hover:
		return .Engaged_Hover
	case engaged:
		return .Engaged
	case focus && active:
		return .Focus_Active
	case focus && hover:
		return .Focus_Hover
	case focus:
		return .Focus
	case active:
		return .Active
	case hover:
		return .Hover
	case:
		return .Normal
	}
}
