package ui_old

import clay "../../vendor/clay"
import rl "vendor:raylib"

TOOLTIP_MAX_WIDTH :: f32(220)
TOOLTIP_EDGE_PAD :: f32(8) // min distance from screen edge before flipping
TOOLTIP_GAP :: f32(4) // space between anchor and tooltip
TOOLTIP_DELAY :: f64(0.8) // seconds of still hover before showing
TOOLTIP_GRACE :: f64(0.5) // after a tooltip hides, the next one skips the delay for this long
TOOLTIP_MOVE_SLOP :: f32(3) // px of mouse movement that resets the timer

Tooltip_Content :: union {
	string,
	Tooltip_Key_Hint,
}

Tooltip_Key_Hint :: struct {
	label:    string,
	shortcut: string,
}

Tooltip_State :: struct {
	// Written every frame by tooltip_set while something is hovered.
	content:      Tooltip_Content,
	anchor_id:    clay.ElementId,
	active:       bool, // was tooltip_set called this frame?

	// Persistent across frames — tracks the delay timer.
	timer_id:     clay.ElementId, // anchor we are currently timing
	timer_start:  f64, // rl.GetTime() when the current hover began
	timer_mouse:  clay.Vector2, // mouse position when timing started
	visible:      bool, // delay has elapsed; show the tooltip
	last_visible: f64, // rl.GetTime() of the most recent frame a tooltip was shown
	measured_id:  clay.ElementId, // anchor whose tooltip size clay has already laid out
}

tooltip_set :: proc(anchor_id: clay.ElementId, content: Tooltip_Content) {
	state.tooltip.content = content
	state.tooltip.anchor_id = anchor_id
	state.tooltip.active = true
}

// Place the tooltip centered on a side of the anchor (below > above > right >
// left, by available room) and then clamp the cross-axis with `offset` so the
// box never spills past the window. clay's floating layout doesn't clip to the
// viewport, so we do the clamping ourselves using the tooltip's measured size.
@(private)
tooltip_place :: proc(
	bb: clay.BoundingBox,
	tt: clay.Dimensions,
	dims: clay.Dimensions,
) -> (
	attach: clay.FloatingAttachPoints,
	offset: clay.Vector2,
) {
	anchor_cx := bb.x + bb.width / 2
	anchor_cy := bb.y + bb.height / 2

	below_fits := bb.y + bb.height + TOOLTIP_GAP + tt.height + TOOLTIP_EDGE_PAD <= dims.height
	above_fits := bb.y - TOOLTIP_GAP - tt.height - TOOLTIP_EDGE_PAD >= 0
	right_fits := bb.x + bb.width + TOOLTIP_GAP + tt.width + TOOLTIP_EDGE_PAD <= dims.width

	if below_fits || above_fits {
		// Vertical side: center horizontally, clamp x into the viewport.
		if below_fits {
			attach = {
				element = .CenterTop,
				parent  = .CenterBottom,
			}
			offset.y = TOOLTIP_GAP
		} else {
			attach = {
				element = .CenterBottom,
				parent  = .CenterTop,
			}
			offset.y = -TOOLTIP_GAP
		}
		want_x := anchor_cx - tt.width / 2
		clamped_x := clamp(want_x, TOOLTIP_EDGE_PAD, dims.width - tt.width - TOOLTIP_EDGE_PAD)
		offset.x = clamped_x - want_x
	} else {
		// Horizontal side: center vertically, clamp y into the viewport.
		if right_fits {
			attach = {
				element = .LeftCenter,
				parent  = .RightCenter,
			}
			offset.x = TOOLTIP_GAP
		} else {
			attach = {
				element = .RightCenter,
				parent  = .LeftCenter,
			}
			offset.x = -TOOLTIP_GAP
		}
		want_y := anchor_cy - tt.height / 2
		clamped_y := clamp(want_y, TOOLTIP_EDGE_PAD, dims.height - tt.height - TOOLTIP_EDGE_PAD)
		offset.y = clamped_y - want_y
	}
	return
}

tooltip_flush :: proc() {
	t := &state.tooltip
	defer t.active = false

	if !t.active {
		// Nothing hovered — reset everything.
		t.timer_id = {}
		t.timer_start = 0
		t.visible = false
		t.measured_id = {}
		return
	}

	now := rl.GetTime()
	mouse := state.mouse

	// Anchor changed → restart timer. But if another tooltip was visible within
	// the grace window, the system is "warmed up": skip the delay and show the
	// new tooltip immediately at its own position.
	if t.anchor_id.id != t.timer_id.id {
		t.timer_id = t.anchor_id
		t.timer_mouse = mouse
		if now - t.last_visible <= TOOLTIP_GRACE {
			t.timer_start = now - TOOLTIP_DELAY // delay already satisfied
			t.visible = true
		} else {
			t.timer_start = now
			t.visible = false
		}
	}

	// Mouse moved too far → restart timer (only before the tooltip is visible).
	if !t.visible {
		dx := mouse.x - t.timer_mouse.x
		dy := mouse.y - t.timer_mouse.y
		if dx * dx + dy * dy > TOOLTIP_MOVE_SLOP * TOOLTIP_MOVE_SLOP {
			t.timer_start = now
			t.timer_mouse = mouse
		}
	}

	// Delay elapsed → latch visible (don't un-latch while same anchor is hovered).
	if now - t.timer_start >= TOOLTIP_DELAY {
		t.visible = true
	}

	if !t.visible do return

	// Remember we showed a tooltip this frame so a quick move to the next
	// element keeps the warmed-up window alive.
	t.last_visible = now

	data := clay.GetElementData(t.anchor_id)
	if !data.found do return

	// Read back last frame's measured tooltip size so we can center and clamp.
	// We only learn the real size one frame *after* the content is laid out, so
	// `tt_data` is trustworthy only when it was measured for the current anchor.
	tt_id := clay.ID("__tooltip")
	tt_data := clay.GetElementData(tt_id)
	tt_dims := clay.Dimensions{TOOLTIP_MAX_WIDTH, 30}
	if tt_data.found {
		tt_dims = {tt_data.boundingBox.width, tt_data.boundingBox.height}
	}

	attach, offset := tooltip_place(data.boundingBox, tt_dims, canvas_dims())

	// On the first frame for a new anchor the size above is stale/estimated, so
	// the computed offset would place the box wrong for one frame (the visible
	// "teleport" flash). Render it off-screen that single frame to let clay
	// measure it, then position it correctly once measured matches the anchor.
	measured := tt_data.found && t.measured_id.id == t.anchor_id.id
	t.measured_id = t.anchor_id
	if !measured {
		offset = {-10000, -10000}
	}

	if clay.UI(tt_id)(
	{
		floating = {
			parentId = t.anchor_id.id,
			attachTo = .ElementWithId,
			attachment = attach,
			offset = offset,
			zIndex = 9999,
			pointerCaptureMode = .Passthrough,
		},
		layout = {
			padding = {left = 10, right = 10, top = 6, bottom = 6},
			childGap = 6,
			childAlignment = {x = .Left, y = .Center},
			sizing = {width = clay.SizingFit(), height = clay.SizingFit()},
		},
		backgroundColor = COLOR_TOOLTIP_BG,
		border = {width = clay.BorderAll(1), color = COLOR_TOOLTIP_BORDER},
		cornerRadius = clay.CornerRadiusAll(0.3),
	},
	) {
		if clay.UI()(
		{
			layout = {
				sizing = {
					width = clay.SizingFit({max = TOOLTIP_MAX_WIDTH}),
					height = clay.SizingFit(),
				},
			},
		},
		) {
			switch c in t.content {
			case string:
				clay.Text(
					c,
					{
						fontSize = 14,
						fontId = u16(FONT.BODY_REG_14),
						textColor = COLOR_TOOLTIP_TEXT,
					},
				)

			case Tooltip_Key_Hint:
				clay.Text(
					c.label,
					{
						fontSize = 12,
						fontId = u16(FONT.BODY_REG_14),
						textColor = COLOR_TOOLTIP_TEXT,
					},
				)
				if c.shortcut != "" {
					if clay.UI()(
					{
						layout = {
							padding = {left = 5, right = 5, top = 2, bottom = 2},
							sizing = {width = clay.SizingFit(), height = clay.SizingFit()},
						},
						backgroundColor = COLOR_TOOLTIP_SHORTCUT_BG,
						cornerRadius = clay.CornerRadiusAll(0.3),
					},
					) {
						clay.Text(
							c.shortcut,
							{
								fontSize = 11,
								fontId = u16(FONT.BODY_BLD_14),
								textColor = COLOR_TOOLTIP_TEXT,
							},
						)
					}
				}
			}
		}
	}
}
