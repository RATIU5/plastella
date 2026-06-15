package ui

import clay "../../vendor/clay"
import rl "vendor:raylib"

TOOLTIP_MAX_WIDTH  :: f32(220)
TOOLTIP_EDGE_PAD   :: f32(8)   // min distance from screen edge before flipping
TOOLTIP_DELAY      :: f64(0.8) // seconds of still hover before showing
TOOLTIP_MOVE_SLOP  :: f32(3)   // px of mouse movement that resets the timer

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
	content:   Tooltip_Content,
	anchor_id: clay.ElementId,
	active:    bool,           // was tooltip_set called this frame?

	// Persistent across frames — tracks the delay timer.
	timer_id:    clay.ElementId, // anchor we are currently timing
	timer_start: f64,            // rl.GetTime() when the current hover began
	timer_mouse: clay.Vector2,   // mouse position when timing started
	visible:     bool,           // delay has elapsed; show the tooltip
}

tooltip_set :: proc(anchor_id: clay.ElementId, content: Tooltip_Content) {
	state.tooltip.content   = content
	state.tooltip.anchor_id = anchor_id
	state.tooltip.active    = true
}

@(private)
tooltip_attach :: proc(bb: clay.BoundingBox, dims: clay.Dimensions) -> clay.FloatingAttachPoints {
	below_fits := bb.y + bb.height + TOOLTIP_EDGE_PAD < dims.height
	right_fits  := bb.x + TOOLTIP_MAX_WIDTH + TOOLTIP_EDGE_PAD < dims.width

	if below_fits {
		if right_fits do return {element = .LeftTop,    parent = .LeftBottom}
		return              {element = .RightTop,   parent = .RightBottom}
	}
	if right_fits do return     {element = .LeftBottom, parent = .LeftTop}
	return                      {element = .RightBottom, parent = .RightTop}
}

tooltip_flush :: proc() {
	t := &state.tooltip
	defer t.active = false

	if !t.active {
		// Nothing hovered — reset everything.
		t.timer_id = {}
		t.timer_start = 0
		t.visible = false
		return
	}

	now   := rl.GetTime()
	mouse := state.mouse

	// Anchor changed → restart timer.
	if t.anchor_id.id != t.timer_id.id {
		t.timer_id    = t.anchor_id
		t.timer_start = now
		t.timer_mouse = mouse
		t.visible     = false
	}

	// Mouse moved too far → restart timer.
	dx := mouse.x - t.timer_mouse.x
	dy := mouse.y - t.timer_mouse.y
	if dx*dx + dy*dy > TOOLTIP_MOVE_SLOP * TOOLTIP_MOVE_SLOP {
		t.timer_start = now
		t.timer_mouse = mouse
		t.visible     = false
	}

	// Delay elapsed → latch visible (don't un-latch while same anchor is hovered).
	if now - t.timer_start >= TOOLTIP_DELAY {
		t.visible = true
	}

	if !t.visible do return

	data := clay.GetElementData(t.anchor_id)
	if !data.found do return

	attach := tooltip_attach(data.boundingBox, canvas_dims())

	if clay.UI(clay.ID("__tooltip"))(
	{
		floating = {
			parentId           = t.anchor_id.id,
			attachTo           = .ElementWithId,
			attachment         = attach,
			offset             = {0, 4},
			zIndex             = 9999,
			pointerCaptureMode = .Passthrough,
		},
		layout = {
			padding        = {left = 10, right = 10, top = 6, bottom = 6},
			childGap       = 6,
			childAlignment = {x = .Left, y = .Center},
			sizing         = {width = clay.SizingFit(), height = clay.SizingFit()},
		},
		backgroundColor = COLOR_TOOLTIP_BG,
		cornerRadius    = clay.CornerRadiusAll(0.3),
	},
	) {
		if clay.UI()(
		{
			layout = {
				sizing = {
					width  = clay.SizingFit({max = TOOLTIP_MAX_WIDTH}),
					height = clay.SizingFit(),
				},
			},
		},
		) {
			switch c in t.content {
			case string:
				clay.Text(
					c,
					{fontSize = 12, fontId = u16(FONT.BODY_REG_14), textColor = COLOR_TOOLTIP_TEXT},
				)

			case Tooltip_Key_Hint:
				clay.Text(
					c.label,
					{fontSize = 12, fontId = u16(FONT.BODY_REG_14), textColor = COLOR_TOOLTIP_TEXT},
				)
				if c.shortcut != "" {
					if clay.UI()(
					{
						layout = {
							padding = {left = 5, right = 5, top = 2, bottom = 2},
							sizing  = {width = clay.SizingFit(), height = clay.SizingFit()},
						},
						backgroundColor = COLOR_TOOLTIP_SHORTCUT_BG,
						cornerRadius    = clay.CornerRadiusAll(0.3),
					},
					) {
						clay.Text(
							c.shortcut,
							{
								fontSize  = 11,
								fontId    = u16(FONT.BODY_BLD_14),
								textColor = COLOR_TOOLTIP_TEXT,
							},
						)
					}
				}
			}
		}
	}
}
