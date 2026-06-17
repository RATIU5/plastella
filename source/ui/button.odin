package ui

import clay "../../vendor/clay"
import api "../api"
import "core:strings"

// Capture ids for buttons live above the 32-bit line so they never collide
// with the platform (1-99) or editor panels (100+) capture ranges. The low
// 32 bits hold the clay element-id hash, making each button's claim unique.
CAPTURE_BUTTON_BIT :: u64(1) << 32

// The visual states a button can be in, in render-priority order. The widget
// resolves exactly one per frame (see `button_state`) and indexes the style's
// `bg`/`fg` ramps with it, so per-state colors live in plain arrays instead of a
// dozen named fields.
Button_State :: enum u8 {
	Normal,
	Hover,
	Active,
	Selected,
	Selected_Hover,
	Selected_Active,
	Disabled,
}

Button_Style :: struct {
	bg:           [Button_State]clay.Color,
	fg:           [Button_State]clay.Color,
	border:       clay.Color,
	padding:      clay.Padding,
	radius:       f32,
	border_width: u16,
	font:         FONT,
	font_size:    u16,
	width_type:   WIDTH_TYPE,
}

// What the button did this frame. `held` is true only while a press that
// *started* on this button is still down; `clicked` fires once, on release
// over the button (standard click semantics).
Button_Result :: struct {
	clicked: bool,
	hovered: bool,
	held:    bool,
}

// Max gap (seconds) between two clicks on the same button to count as a double.
DOUBLE_CLICK_S :: 0.4

// ponytail: single global slot — only one pointer, so only one button can be
// mid-double-click. Make this a small map if multi-pointer ever matters.
@(private)
last_click: struct {
	eid: u32,
	t:   f64,
}

// Record a click and report whether it completes a double-click on `eid`.
register_click :: proc(eid: u32, t: f64) -> (double: bool) {
	double = eid == last_click.eid && t - last_click.t <= DOUBLE_CLICK_S
	// Reset on a double so a triple click isn't read as two doubles.
	last_click = double ? {} : {eid, t}
	return
}

// Resolve the single visual state for this frame so the label/icon and the
// background stay in sync (both index the same state). Priority: disabled and
// active (pressed) dominate; hovering an already-selected control gets its own
// state so the label can take an emphasized tint.
button_state :: proc(active, hovered, selected, disabled: bool) -> Button_State {
	switch {
	case disabled:
		return .Disabled
	case selected && active:
		return .Selected_Active
	case selected && hovered:
		return .Selected_Hover
	case active:
		return .Active
	case selected:
		return .Selected
	case hovered:
		return .Hover
	case:
		return .Normal
	}
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
	tooltip: Tooltip_Content = nil,
	disabled := false,
	radius: Maybe(clay.CornerRadius) = nil,
	border: Maybe(clay.BorderWidth) = nil,
) -> Button_Result {
	result: Button_Result

	// Hit-test against last frame's geometry so we can decide the press state
	// *before* opening the element, keeping the visuals lag-free.
	eid := clay.ID(id, index)
	cap := api.Capture(u64(eid.id) | CAPTURE_BUTTON_BIT)

	// A disabled button is inert: it never hit-tests, captures, clicks, or
	// shows a tooltip. Skip all interaction so `result` stays zeroed and the
	// visuals resolve to the muted disabled palette below.
	hovered := !disabled && clay.PointerOver(eid)
	active := false

	if !disabled {
		result.hovered = hovered

		// Claim the mouse only when the press *begins* over the button. A press
		// that started elsewhere never owns this capture, so dragging onto the
		// button while held does not activate it.
		if hovered && input.left_pressed {
			api.capture_mouse(input, cap)
		}

		owns := api.has_capture(input, cap)
		result.held = owns && input.left_down
		active = result.held && hovered // drag off -> not active, drag back -> active

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
			// The widget owns the element id, so it also owns the tooltip anchor.
			// `nil` content (the default) means this button opted out.
			if tooltip != nil {
				tooltip_set(eid, tooltip)
			}
		}
	} else if clay.PointerOver(eid) {
		// Inert, but signal non-interactivity while the cursor is over it.
		input.cursor = .Not_Allowed
	}

	sizing: clay.Sizing = {
		height = clay.SizingFit(),
		width  = clay.SizingFit(),
	}
	if style.width_type == .GROW {
		sizing.width = clay.SizingGrow()
	}

	st := button_state(active, hovered, selected, disabled)
	bg := style.bg[st]
	fg := style.fg[st]

	// Group members override per-corner radius and per-side border so each
	// button's own element carries both — keeping border and background corners
	// in lockstep. Standalone buttons use the uniform style values.
	corner := radius.? or_else clay.CornerRadiusAll(style.radius)
	bord := border.? or_else clay.BorderAll(style.border_width)

	if clay.UI(clay.ID(id, index))(
	{
		layout = {
			padding = style.padding,
			childAlignment = {x = .Center, y = .Center},
			sizing = sizing,
		},
		border = {width = bord, color = style.border},
		backgroundColor = bg,
		cornerRadius = corner,
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
	tooltip: Tooltip_Content = nil,
	disabled := false,
) -> Button_Result {
	result: Button_Result

	// Hit-test against last frame's geometry so we can decide the press state
	// *before* opening the element, keeping the visuals lag-free.
	eid := clay.ID(id, index)
	cap := api.Capture(u64(eid.id) | CAPTURE_BUTTON_BIT)

	// A disabled button is inert: it never hit-tests, captures, clicks, or
	// shows a tooltip. Skip all interaction so `result` stays zeroed and the
	// visuals resolve to the muted disabled palette below.
	hovered := !disabled && clay.PointerOver(eid)
	active := false

	if !disabled {
		result.hovered = hovered

		// Claim the mouse only when the press *begins* over the button. A press
		// that started elsewhere never owns this capture, so dragging onto the
		// button while held does not activate it.
		if hovered && input.left_pressed {
			api.capture_mouse(input, cap)
		}

		owns := api.has_capture(input, cap)
		result.held = owns && input.left_down
		active = result.held && hovered // drag off -> not active, drag back -> active

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
			// The widget owns the element id, so it also owns the tooltip anchor.
			// `nil` content (the default) means this button opted out.
			if tooltip != nil {
				tooltip_set(eid, tooltip)
			}
		}
	} else if clay.PointerOver(eid) {
		// Inert, but signal non-interactivity while the cursor is over it.
		input.cursor = .Default
	}

	sizing: clay.Sizing = {
		height = clay.SizingFit(),
		width  = clay.SizingFit(),
	}
	if style.width_type == .GROW {
		sizing.width = clay.SizingGrow()
	}

	st := button_state(active, hovered, selected, disabled)
	bg := style.bg[st]
	fg := style.fg[st]

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
	button_group_bordered,
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

// Buttons joined into one bordered block with no gaps: the container draws the
// outer border plus a single `betweenChildren` line between adjacent buttons,
// so neighbors share one border instead of stacking two. The buttons draw no
// border of their own and the block has no corner radius. `vertical` stacks
// top-to-bottom; otherwise left-to-right.
button_group_bordered :: proc(
	id: string,
	labels: []string,
	selected: int,
	style: Button_Style,
	input: ^api.Input,
	vertical := false,
) -> (
	clicked: int,
) {
	clicked = -1

	// Each button grows to fill the block and carries its own border + corner
	// radius, so border and background corners always agree. The shared seam is
	// drawn by one neighbor only (the leading edge of every non-first button),
	// so adjacent buttons get one line, not two.
	btn_style := style
	btn_style.width_type = .GROW
	dir: clay.LayoutDirection = vertical ? .TopToBottom : .LeftToRight
	bw := style.border_width
	r := style.radius
	last := len(labels) - 1

	// Container grows only when the buttons do, so a FIT group hugs its content.
	csize: clay.Sizing
	if style.width_type == .GROW do csize.width = clay.SizingGrow()

	if clay.UI()({layout = {layoutDirection = dir, sizing = csize}}) {
		for label, i in labels {
			bord: clay.BorderWidth
			corner: clay.CornerRadius
			if vertical {
				bord = {
					left   = bw,
					right  = bw,
					top    = bw,
					bottom = i == last ? bw : 0,
				}
				if i == 0 do corner.topLeft, corner.topRight = r, r
				if i == last do corner.bottomLeft, corner.bottomRight = r, r
			} else {
				bord = {
					top    = bw,
					bottom = bw,
					left   = bw,
					right  = i == last ? bw : 0,
				}
				if i == 0 do corner.topLeft, corner.bottomLeft = r, r
				if i == last do corner.topRight, corner.bottomRight = r, r
			}

			res := button(
				id,
				label,
				btn_style,
				input,
				u32(i),
				selected == i,
				radius = corner,
				border = bord,
			)
			if res.clicked {
				clicked = i
			}
		}
	}

	return
}
