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
COLOR_GREY_65 :: [4]f32{235, 235, 234, 255}
COLOR_GREY_105 :: [4]f32{225, 225, 223, 255}
COLOR_GREY_150 :: [4]f32{211, 210, 208, 255}
COLOR_GREY_195 :: [4]f32{198, 197, 194, 255}
COLOR_GREY_240 :: [4]f32{186, 185, 181, 255}
COLOR_GREY_290 :: [4]f32{171, 170, 165, 255}
COLOR_GREY_340 :: [4]f32{156, 154, 150, 255}
COLOR_GREY_395 :: [4]f32{142, 139, 134, 255}
COLOR_GREY_445 :: [4]f32{126, 124, 118, 255}
COLOR_GREY_500 :: [4]f32{109, 107, 102, 255}
COLOR_GREY_555 :: [4]f32{97, 96, 91, 255}
COLOR_GREY_605 :: [4]f32{87, 85, 81, 255}
COLOR_GREY_660 :: [4]f32{74, 72, 69, 255}
COLOR_GREY_710 :: [4]f32{63, 62, 59, 255}
COLOR_GREY_760 :: [4]f32{49, 49, 49, 255}
COLOR_GREY_805 :: [4]f32{42, 41, 39, 255}
COLOR_GREY_850 :: [4]f32{32, 32, 32, 255}
COLOR_GREY_895 :: [4]f32{24, 23, 22, 255}
COLOR_GREY_935 :: [4]f32{13, 13, 12, 255}
COLOR_GREY_970 :: [4]f32{5, 5, 5, 255}

COLOR_ACCENT :: [4]f32{70, 136, 242, 255}

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
