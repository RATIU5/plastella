package app

import "../../vendor/clay"

// Floating message anchored to another element, kept fully inside the window.
// Takes no layout space, so it can be called from anywhere in the tree.
Tooltip_Style :: struct {
	font:         Text,
	padding:      clay.Padding,
	border_width: clay.BorderWidth,
	bg_color:     clay.Color,
	fg_color:     clay.Color,
	radius:       clay.CornerRadius,
	gap:          f32, // between anchor and tooltip
	margin:       f32, // minimum distance from the window edge
	max_width:    f32,
}

Tooltip_Theme :: enum u8 {
	Default,
}

@(rodata)
tooltip_styles := [Tooltip_Theme]Tooltip_Style {
	.Default = {
		font = .UI_REG_12,
		padding = {8, 8, 5, 5},
		border_width = {1, 1, 1, 1, 0},
		bg_color = COLOR_GREY_805,
		fg_color = COLOR_GREY_150,
		radius = {5, 5, 5, 5},
		gap = 6,
		margin = 6,
		max_width = 260,
	},
}

/*
Draws `message` under the element with `anchor_id`, flipping above when it would
run off the bottom. `color` is the border color, so the caller can express state
(e.g. Text_Input_Result.color for validity).

Nothing is drawn on the first frame the anchor exists: its box comes from clay's
previous layout, like every other position query in this codebase.
*/
tooltip :: proc(
	ctx: ^Ctx,
	id: string,
	anchor_id: string,
	message: string,
	color: clay.Color,
	theme := Tooltip_Theme.Default,
) {
	if message == "" do return

	anchor := clay.GetElementData(clay.ID(anchor_id))
	if !anchor.found do return

	style := tooltip_styles[theme]
	_, glyph_h := text_metrics(style.font, ctx.frame.assets)

	inner_w := min(
		text_width(message, style.font, ctx.frame.assets),
		style.max_width - f32(style.padding.left + style.padding.right),
	)
	w := inner_w + f32(style.padding.left + style.padding.right)
	h := glyph_h + f32(style.padding.top + style.padding.bottom)

	flip, nudge := tooltip_fit(anchor.boundingBox, {w, h}, ctx.frame.screen, style)
	below := clay.FloatingAttachPoints {
		element = .CenterTop,
		parent  = .CenterBottom,
	}
	above := clay.FloatingAttachPoints {
		element = .CenterBottom,
		parent  = .CenterTop,
	}

	if clay.UI(clay.ID(id))(
	{
		floating = {
			attachTo = .ElementWithId,
			parentId = clay.ID(anchor_id).id,
			clipTo = .None,
			zIndex = 10,
			attachment = above if flip else below,
			offset = {nudge.x, nudge.y + (-style.gap if flip else style.gap)},
			pointerCaptureMode = .Passthrough,
		},
		layout = {
			padding = style.padding,
			sizing = {width = clay.SizingFixed(w), height = clay.SizingFixed(h)},
			childAlignment = {y = .Center},
		},
		backgroundColor = style.bg_color,
		border = {width = style.border_width, color = color},
		cornerRadius = style.radius,
	},
	) {
		text(ctx.frame.assets, message, style.font, style.fg_color, .Left, .None, inner_w)
	}
}

/*
Whether to flip above the anchor, and how far to push the tooltip back inside the
window. `nudge` is a correction to clay's own centered placement, not an absolute
position: both sides of the subtraction use the same (previous-frame) anchor box, so
it comes out exactly 0 whenever the tooltip already fits - which is the common case.
Only a tooltip actually hugging a window edge trails the anchor by a frame.
*/
@(private = "file", require_results)
tooltip_fit :: proc(
	anchor: clay.BoundingBox,
	size: [2]f32,
	screen: [2]f32,
	style: Tooltip_Style,
) -> (
	flip: bool,
	nudge: clay.Vector2,
) {
	m := style.margin
	x := anchor.x + (anchor.width - size.x) * 0.5
	y := anchor.y + anchor.height + style.gap

	flip = y + size.y > screen.y - m
	if flip do y = anchor.y - size.y - style.gap

	// max() keeps the low bound winning, so a window shorter than the tooltip still
	// shows its top-left rather than clamping it out of view.
	nudge.x = clamp(x, m, max(m, screen.x - m - size.x)) - x
	nudge.y = clamp(y, m, max(m, screen.y - m - size.y)) - y
	return
}
