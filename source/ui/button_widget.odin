package ui

import clay "../../vendor/clay"
import api "../api"
import "core:strings"

// Capture ids for buttons live above the 32-bit line so they never collide
// with the platform (1-99) or editor panels (100+) capture ranges. The low
// 32 bits hold the clay element-id hash, making each button's claim unique.
CAPTURE_BUTTON_BIT :: u64(1) << 32

Button_Style :: struct {
	bg:            clay.Color,
	bg_hover:      clay.Color,
	bg_active:     clay.Color,
	bg_selected:   clay.Color,
	text:          clay.Color,
	text_hover:    clay.Color,
	text_active:   clay.Color,
	text_selected: clay.Color,
	border:        clay.Color,
	padding:       clay.Padding,
	radius:        f32,
	border_width:  u16,
	font:          FONT,
	font_size:     u16,
	width_type:    WIDTH_TYPE,
}

// What the button did this frame. `held` is true only while a press that
// *started* on this button is still down; `clicked` fires once, on release
// over the button (standard click semantics).
Button_Result :: struct {
	clicked: bool,
	hovered: bool,
	held:    bool,
}

// Resolve the state-dependent colors once so the label/icon and background
// stay in sync. active > hover > selected > base, matching the visual priority.
button_bg :: proc(style: Button_Style, active, hovered, selected: bool) -> clay.Color {
	switch {
	case active:
		return style.bg_active
	case hovered:
		return style.bg_hover
	case selected:
		return style.bg_selected
	case:
		return style.bg
	}
}

button_fg :: proc(style: Button_Style, active, hovered, selected: bool) -> clay.Color {
	switch {
	case active:
		return style.text_active
	case hovered:
		return style.text_hover
	case selected:
		return style.text_selected
	case:
		return style.text
	}
}

PRIMARY_BUTTON :: Button_Style {
	bg = COLOR_BUTTON_ACCENT,
	bg_hover = COLOR_BUTTON_ACCENT_HOVER,
	bg_active = COLOR_BUTTON_ACCENT_ACTIVE,
	bg_selected = COLOR_BUTTON_ACCENT_SELECTED,
	text = COLOR_BUTTON_TEXT,
	text_hover = COLOR_BUTTON_TEXT,
	text_active = COLOR_BUTTON_TEXT,
	text_selected = COLOR_BUTTON_TEXT,
	border = COLOR_BUTTON_BORDER,
	padding = {left = 10, right = 10, top = 5, bottom = 5},
	radius = 0.5,
	border_width = 1,
	font = .BODY_REG_14,
	font_size = 14,
	width_type = .FIT,
}

ICON_BUTTON :: Button_Style {
	bg = COLOR_TRANSPARENT,
	bg_hover = COLOR_BUTTON_ACCENT_HOVER,
	bg_active = COLOR_BUTTON_ACCENT_ACTIVE,
	bg_selected = COLOR_BUTTON_ACCENT_SELECTED,
	text = COLOR_BUTTON_ICON,
	text_hover = COLOR_BUTTON_ICON_HOVER,
	text_active = COLOR_BUTTON_ICON_ACTIVE,
	text_selected = COLOR_BUTTON_ICON,
	border = COLOR_TRANSPARENT,
	padding = {left = 5, right = 5, top = 5, bottom = 5},
	radius = 0.5,
	border_width = 0,
	font = .BODY_REG_14,
	font_size = 18,
	width_type = .FIT,
}

// `index` disambiguates the clay id when the same `id` is reused (loops,
// groups); `selected` paints the persistent selected color (segmented
// controls), distinct from the momentary active/pressed color.
button_text :: proc(
	id: string,
	label: string,
	style: Button_Style,
	input: ^api.Input,
	index: u32 = 0,
	selected := false,
) -> Button_Result {
	result: Button_Result

	// Hit-test against last frame's geometry so we can decide the press state
	// *before* opening the element, keeping the visuals lag-free.
	eid := clay.ID(id, index)
	cap := api.Capture(u64(eid.id) | CAPTURE_BUTTON_BIT)
	hovered := clay.PointerOver(eid)
	result.hovered = hovered

	// Claim the mouse only when the press *begins* over the button. A press
	// that started elsewhere never owns this capture, so dragging onto the
	// button while held does not activate it.
	if hovered && input.left_pressed {
		api.capture_mouse(input, cap)
	}

	owns := api.has_capture(input, cap)
	result.held = owns && input.left_down
	active := result.held && hovered // drag off -> not active, drag back -> active

	// Resolve the press on mouse-up: a click counts only if we still own the
	// press and the cursor is over the button. Release the capture either way.
	if owns && input.left_released {
		if hovered {
			result.clicked = true
		}
		api.release_capture(input, cap)
	}

	if hovered {
		input.cursor = .Pointer
	}

	sizing: clay.Sizing = {
		height = clay.SizingFit(),
		width  = clay.SizingFit(),
	}
	if style.width_type == .GROW {
		sizing.width = clay.SizingGrow()
	}

	bg := button_bg(style, active, hovered, selected)
	fg := button_fg(style, active, hovered, selected)

	if clay.UI(clay.ID(id, index))(
	{
		layout = {
			padding = style.padding,
			childAlignment = {x = .Center, y = .Center},
			sizing = sizing,
		},
		border = {width = clay.BorderAll(style.border_width), color = style.border},
		backgroundColor = bg,
		cornerRadius = clay.CornerRadiusAll(style.radius),
	},
	) {
		clay.Text(label, {fontSize = style.font_size, fontId = u16(style.font), textColor = fg})
	}

	return result
}

// `index` disambiguates the clay id when the same `id` is reused (loops,
// groups); `selected` paints the persistent selected color (segmented
// controls), distinct from the momentary active/pressed color.
button_icon :: proc(
	id: string,
	icon: ^Icon,
	style: Button_Style,
	input: ^api.Input,
	index: u32 = 0,
	selected := false,
) -> Button_Result {
	result: Button_Result

	// Hit-test against last frame's geometry so we can decide the press state
	// *before* opening the element, keeping the visuals lag-free.
	eid := clay.ID(id, index)
	cap := api.Capture(u64(eid.id) | CAPTURE_BUTTON_BIT)
	hovered := clay.PointerOver(eid)
	result.hovered = hovered

	// Claim the mouse only when the press *begins* over the button. A press
	// that started elsewhere never owns this capture, so dragging onto the
	// button while held does not activate it.
	if hovered && input.left_pressed {
		api.capture_mouse(input, cap)
	}

	owns := api.has_capture(input, cap)
	result.held = owns && input.left_down
	active := result.held && hovered // drag off -> not active, drag back -> active

	// Resolve the press on mouse-up: a click counts only if we still own the
	// press and the cursor is over the button. Release the capture either way.
	if owns && input.left_released {
		if hovered {
			result.clicked = true
		}
		api.release_capture(input, cap)
	}

	if hovered {
		input.cursor = .Pointer
	}

	sizing: clay.Sizing = {
		height = clay.SizingFit(),
		width  = clay.SizingFit(),
	}
	if style.width_type == .GROW {
		sizing.width = clay.SizingGrow()
	}

	bg := button_bg(style, active, hovered, selected)
	fg := button_fg(style, active, hovered, selected)

	if clay.UI(clay.ID(id, index))(
	{
		layout = {
			padding = style.padding,
			childAlignment = {x = .Center, y = .Center},
			sizing = sizing,
		},
		border = {width = clay.BorderAll(style.border_width), color = style.border},
		backgroundColor = bg,
		cornerRadius = clay.CornerRadiusAll(style.radius),
	},
	) {
		id_icon := strings.concatenate([]string{id, "_icon"}, context.temp_allocator)

		// Copy the icon so each button instance has its own tint. The shared
		// *Icon pointer would otherwise let the last button overwrite all prior
		// tints before clay_render reads them back.
		icon_inst := new(Icon, context.temp_allocator)
		icon_inst^ = icon^
		icon_inst.tint = fg

		// font_size is the style's single content size: it sets the icon's
		// rendered height, with width derived from the source aspect so
		// non-square glyphs aren't distorted. The Icon supplies pixels/aspect,
		// the style owns the size.
		icon_h := f32(style.font_size)
		icon_w := icon_h * (icon_inst.src.width / icon_inst.src.height)

		if clay.UI(clay.ID(id_icon, index))(
		{
			layout = {
				sizing = {width = clay.SizingFixed(icon_w), height = clay.SizingFixed(icon_h)},
			},
			image = {imageData = rawptr(icon_inst)},
			aspectRatio = {icon_inst.src.width / icon_inst.src.height},
		},
		) {}
	}

	return result
}

button :: proc {
	button_text,
	button_icon,
}


// Lays `labels` out in a row and tracks single selection. `selected` is the
// caller-owned index of the highlighted button (-1 for none); the return is
// the index clicked this frame, or -1. The caller updates its own state:
//   if hit := ui.button_group("Tabs", tabs, current, ui.PRIMARY_BUTTON, input); hit >= 0 {
//       current = hit
//   }
button_group :: proc(
	id: string,
	labels: []string,
	selected: int,
	style: Button_Style,
	input: ^api.Input,
	gap: u16 = 0,
) -> (
	clicked: int,
) {
	clicked = -1

	// Anonymous container: its auto id stays clear of the buttons' explicit
	// `clay.ID(id, i)`, so children never collide with the group.
	if clay.UI()({layout = {childGap = gap, childAlignment = {y = .Center}}}) {
		for label, i in labels {
			res := button(id, label, style, input, u32(i), selected == i)
			if res.clicked {
				clicked = i
			}
		}
	}

	return
}
