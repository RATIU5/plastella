package ui

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

@(private)
GREY_30 :: [4]f32{245, 245, 244, 255}
@(private)
GREY_65 :: [4]f32{235, 235, 234, 255}
@(private)
GREY_105 :: [4]f32{225, 225, 223, 255}
@(private)
GREY_150 :: [4]f32{211, 210, 208, 255}
@(private)
GREY_195 :: [4]f32{198, 197, 194, 255}
@(private)
GREY_240 :: [4]f32{186, 185, 181, 255}
@(private)
GREY_290 :: [4]f32{171, 170, 165, 255}
@(private)
GREY_340 :: [4]f32{156, 154, 150, 255}
@(private)
GREY_395 :: [4]f32{142, 139, 134, 255}
@(private)
GREY_445 :: [4]f32{126, 124, 118, 255}
@(private)
GREY_500 :: [4]f32{109, 107, 102, 255}
@(private)
GREY_555 :: [4]f32{97, 96, 91, 255}
@(private)
GREY_605 :: [4]f32{87, 85, 81, 255}
@(private)
GREY_660 :: [4]f32{74, 72, 69, 255}
@(private)
GREY_710 :: [4]f32{63, 62, 59, 255}
@(private)
GREY_760 :: [4]f32{53, 52, 49, 255}
@(private)
GREY_805 :: [4]f32{42, 41, 39, 255}
@(private)
GREY_850 :: [4]f32{32, 31, 30, 255}
@(private)
GREY_895 :: [4]f32{24, 23, 22, 255}
@(private)
GREY_935 :: [4]f32{13, 13, 12, 255}
@(private)
GREY_970 :: [4]f32{5, 5, 5, 255}

opacity :: #force_inline proc "contextless" (color: [4]f32, opacity: u8 = 255) -> [4]f32 {
	return {color.r, color.g, color.b, f32(opacity)}
}

TRANSPARENT :: [4]f32{0, 0, 0, 0}

ACCENT :: [4]f32{70, 136, 242, 255}

COLOR_TEXT :: GREY_30
COLOR_NO_PROJECT_TEXT :: GREY_395

COLOR_SIDEBAR :: GREY_935
COLOR_SIDEBAR_FOOTER :: GREY_895
COLOR_SIDEBAR_BORDER :: GREY_805
COLOR_SIDEBAR_BORDER_HOVER :: GREY_760
COLOR_SIDEBAR_BORDER_ACTIVE :: ACCENT
