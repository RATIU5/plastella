package ui_old

import clay "../../vendor/clay"
import api "../api"

// Inset between the toast and the window edges, so the box floats clear of the
// corner instead of sitting flush against it.
DEV_NOTICE_MARGIN :: f32(10)

// Dismissible dev HUD toast pinned near the bottom edge. The hot-reload host
// (via the app) shows it when a code change can't be applied cleanly; it stays
// up until the dev clicks its X and re-appears on each new blocked change. State
// is a package global because it only needs to persist while NOT reloading — a
// clean reload zeroes it, which correctly clears a stale notice.
@(private)
dev_notice_text: string
@(private)
dev_notice_visible: bool

// Show the toast with `text` (or refresh it). Edge-triggered: call once per new
// notice, not every frame, so a dev dismissal isn't immediately overridden.
dev_notice_show :: proc(text: string) {
	dev_notice_text = text
	dev_notice_visible = true
}

// Hide the toast (e.g. after the host applies a clean reload/restart).
dev_notice_hide :: proc() {
	dev_notice_visible = false
}

// Declare the toast as a clay floating bar near the window's bottom edge,
// reusing the icon button for a native-feeling close control. Must be called
// inside the layout (between frame_begin/frame_end) and is given `input` so the
// X button participates in the normal capture/click flow. `pointerCaptureMode =
// .Capture` stops clicks on the bar from leaking to panels beneath it.
dev_notice_render :: proc(input: ^api.Input) {
	if !dev_notice_visible {
		return
	}

	// Outer floating strip spans the bottom edge but stays transparent; its
	// padding is the gap between the visible card and the window edges. A single
	// floating element can only be *positioned*, not inset on every side, so the
	// margin lives here and the card grows inside it.
	if clay.UI(clay.ID("__dev_notice"))(
	{
		floating = {
			attachTo = .Root,
			attachment = {element = .LeftBottom, parent = .LeftBottom},
			zIndex = 10000,
			pointerCaptureMode = .Capture,
		},
		layout = {
			sizing = {width = clay.SizingFixed(canvas_dims().width), height = clay.SizingFit()},
			padding = clay.PaddingAll(u16(DEV_NOTICE_MARGIN)),
		},
	},
	) {
		// The visible card: grows to fill the strip minus the margin padding.
		if clay.UI(clay.ID("__dev_notice_card"))(
		{
			layout = {
				sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
				padding = {left = 14, right = 8, top = 7, bottom = 7},
				childGap = 10,
				childAlignment = {x = .Left, y = .Center},
			},
			backgroundColor = COLOR_DEV_NOTICE_BG,
			border = {
				width = {left = 1, right = 1, top = 1, bottom = 1},
				color = COLOR_DEV_NOTICE_BORDER,
			},
			cornerRadius = clay.CornerRadiusAll(0.3),
		},
		) {
			// Message grows to fill, pushing the close button to the right edge.
			if clay.UI()(
			{
				layout = {
					sizing = {width = clay.SizingGrow(), height = clay.SizingFit()},
					childAlignment = {y = .Center},
				},
			},
			) {
				clay.Text(
					dev_notice_text,
					{
						fontSize = 14,
						fontId = u16(FONT.BODY_REG_14),
						textColor = COLOR_DEV_NOTICE_TEXT,
					},
				)
			}

			if button("__dev_notice_close", get_icon(.CLOSE), DEV_NOTICE_CLOSE_BUTTON, input).clicked {
				dev_notice_visible = false
			}
		}
	}
}
