package ui

// ---------------------------------------------------------------------------
// Base palette. Every raw color literal is defined exactly once here; greys are
// named by lightness so a single value is never duplicated under two names.
// Role colors and button ramps below reference these instead of repeating RGBs.
// ---------------------------------------------------------------------------
TRANSPARENT :: [4]f32{0, 0, 0, 0}
WHITE :: [4]f32{225, 225, 225, 255}

GREY_17 :: [4]f32{17, 17, 17, 255}
GREY_24 :: [4]f32{24, 24, 24, 255}
GREY_25 :: [4]f32{25, 25, 25, 255}
GREY_28 :: [4]f32{28, 28, 28, 255}
GREY_30 :: [4]f32{30, 30, 30, 255}
GREY_35 :: [4]f32{35, 35, 35, 255}
GREY_37 :: [4]f32{37, 37, 37, 255}
GREY_46 :: [4]f32{46, 46, 46, 255}
GREY_50 :: [4]f32{50, 50, 50, 255}
GREY_57 :: [4]f32{57, 57, 57, 255}
GREY_60 :: [4]f32{60, 60, 60, 255}
GREY_75 :: [4]f32{75, 75, 75, 255}
GREY_90 :: [4]f32{90, 90, 90, 255}
GREY_140 :: [4]f32{140, 140, 140, 255}
GREY_160 :: [4]f32{160, 160, 160, 255}
GREY_180 :: [4]f32{180, 180, 180, 255}
GREY_218 :: [4]f32{218, 218, 218, 255}
GREY_220 :: [4]f32{220, 220, 220, 255}

ACCENT :: [4]f32{70, 136, 242, 255}

// Warm palette for the dev-only HUD toast (blocked hot reload).
WARN_BG :: [4]f32{38, 26, 26, 255}
WARN_BG_HOVER :: [4]f32{48, 36, 36, 255}
WARN_BORDER :: [4]f32{200, 90, 70, 255}
WARN_TEXT :: [4]f32{232, 196, 188, 255}

// ---------------------------------------------------------------------------
// Role colors used directly by panels. Button colors are not here — they live
// as per-state ramps next to the styles in button_styles.odin.
// ---------------------------------------------------------------------------
COLOR_TEXT :: WHITE
COLOR_NO_PROJECT_TEXT :: GREY_90

COLOR_SIDEBAR :: GREY_17
COLOR_SIDEBAR_FOOTER :: GREY_25
COLOR_SIDEBAR_BORDER :: GREY_37
COLOR_SIDEBAR_BORDER_HOVER :: GREY_57
COLOR_SIDEBAR_BORDER_ACTIVE :: ACCENT

COLOR_TOOLTIP_BG :: GREY_50
COLOR_TOOLTIP_BORDER :: GREY_75
COLOR_TOOLTIP_TEXT :: GREY_220
COLOR_TOOLTIP_SHORTCUT_BG :: GREY_60

COLOR_DEV_NOTICE_BG :: WARN_BG
COLOR_DEV_NOTICE_BORDER :: WARN_BORDER
COLOR_DEV_NOTICE_TEXT :: WARN_TEXT
