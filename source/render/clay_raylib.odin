package render

import clay "../../vendor/clay"
import "core:math"
import "core:mem"
import textures "textures"
import rl "vendor:raylib"
import rlgl "vendor:raylib/rlgl"

CORNER_SEGMENTS :: 16
TEXT_STACK :: 1024

@(private)
draw_begin_rl :: proc(render, screen: [2]i32) {
	rl.BeginDrawing()
	// After display hot-plug, raylib draws at old scale. Rebuild transform deterministically.
	rlgl.Viewport(0, 0, render.x, render.y)
	rlgl.MatrixMode(rlgl.PROJECTION)
	rlgl.LoadIdentity()
	rlgl.Ortho(0, f64(screen.x), f64(screen.y), 0, 0, 1)
	rlgl.MatrixMode(rlgl.MODELVIEW)
	rlgl.LoadIdentity()

	rl.ClearBackground(rl.BLACK)
}

@(private)
draw_end_rl :: proc() {
	rl.EndDrawing()
}

@(private)
render_clay_commands_rl :: proc(cmds: ^clay.ClayArray(clay.RenderCommand)) {
	for i in 0 ..< cmds.length {
		cmd := clay.RenderCommandArray_Get(cmds, i)
		b := cmd.boundingBox

		switch cmd.commandType {
		case .None:

		case .Rectangle:
			draw_rounded_rect_rl(b, cmd.renderData.rectangle)

		case .Text:
			draw_text_rl(b, cmd.renderData.text)

		case .Image:
			draw_image_rl(b, cmd.renderData.image)

		case .Border:
			draw_border_rl(b, cmd.renderData.border)

		case .ScissorStart:
			scissor_start_rl(b)

		case .ScissorEnd:
			scissor_end_rl()

		case .Custom, .OverlayColorStart, .OverlayColorEnd:
		// Not used yet
		}
	}
}

@(private = "file")
draw_rounded_rect_rl :: proc(b: clay.BoundingBox, data: clay.RectangleRenderData) {
	cr := data.cornerRadius
	x := b.x
	y := b.y
	w := b.width
	h := b.height

	color := to_render_color_rl(data.backgroundColor)
	tl := radius_px(cr.topLeft, w, h)
	tr := radius_px(cr.topRight, w, h)
	bl := radius_px(cr.bottomLeft, w, h)
	br := radius_px(cr.bottomRight, w, h)
	tl, tr, bl, br = clamp_radii(tl, tr, bl, br, w, h)

	if tl == 0 && tr == 0 && bl == 0 && br == 0 {
		rl.DrawRectangleRec({x, y, w, h}, color)
		return
	}

	l, r := max(tl, bl), max(tr, br)

	rl.DrawRectangleRec({x + l, y, w - l - r, h}, color) // Center column, full height
	if l > 0 do rl.DrawRectangleRec({x, y + tl, l, h - tl - bl}, color) // left between corners
	if r > 0 do rl.DrawRectangleRec({x + w - r, y + tr, r, h - tr - br}, color) // right

	sector(x + tl, y + tl, tl, 180, 270, color)
	sector(x + w - tr, y + tr, tr, 270, 360, color)
	sector(x + bl, y + h - bl, bl, 90, 180, color)
	sector(x + w - br, y + h - br, br, 0, 90, color)
}

@(private = "file")
draw_border_rl :: proc(box: clay.BoundingBox, bd: clay.BorderRenderData) {
	color := to_render_color_rl(bd.color)
	x, y, w, h := box.x, box.y, box.width, box.height
	tl := radius_px(bd.cornerRadius.topLeft, w, h)
	tr := radius_px(bd.cornerRadius.topRight, w, h)
	bl := radius_px(bd.cornerRadius.bottomLeft, w, h)
	br := radius_px(bd.cornerRadius.bottomRight, w, h)
	tl, tr, bl, br = clamp_radii(tl, tr, bl, br, w, h)

	if bd.width.left > 0 {
		lw := f32(bd.width.left)
		rl.DrawRectangleRec({x, y + tl, lw, h - tl - bl}, color)
	}
	if bd.width.right > 0 {
		rw := f32(bd.width.right)
		rl.DrawRectangleRec({x + w - rw, y + tr, rw, h - tr - br}, color)
	}
	if bd.width.top > 0 {
		tw := f32(bd.width.top)
		rl.DrawRectangleRec({x + tl, y, w - tl - tr, tw}, color)
	}
	if bd.width.bottom > 0 {
		bw := f32(bd.width.bottom)
		rl.DrawRectangleRec({x + bl, y + h - bw, w - bl - br, bw}, color)
	}

	ring(x + tl, y + tl, tl, f32(bd.width.top), 180, 270, color)
	ring(x + w - tr, y + tr, tr, f32(bd.width.top), 270, 360, color)
	ring(x + bl, y + h - bl, bl, f32(bd.width.bottom), 90, 180, color)
	ring(x + w - br, y + h - br, br, f32(bd.width.bottom), 0, 90, color)
}

@(private = "file")
draw_text_rl :: proc(b: clay.BoundingBox, t: clay.TextRenderData) {
	font := state.fonts[FONT(t.fontId)]
	n := int(t.stringContents.length)

	buf: [TEXT_STACK]u8 = ---
	cstr: cstring

	if n < TEXT_STACK {
		mem.copy(&buf[0], t.stringContents.chars, n)
		buf[n] = 0
		cstr = cstring(&buf[0])
	} else {
		tmp := make([]u8, n + 1, context.temp_allocator)
		mem.copy(raw_data(tmp), t.stringContents.chars, n)
		cstr = cstring(raw_data(tmp))
	}

	rl.DrawTextEx(
		font,
		cstr,
		{b.x, b.y},
		f32(t.fontSize),
		f32(t.letterSpacing),
		to_render_color_rl(t.textColor),
	)
}

@(private = "file")
draw_image_rl :: proc(b: clay.BoundingBox, img: clay.ImageRenderData) {
	r := (^textures.Texture_Slice)(img.imageData)
	tint := r.tint == {} ? rl.WHITE : to_render_color_rl(r.tint)
	rl.DrawTexturePro(r.tex^, r.crop, {b.x, b.y, b.width, b.height}, {0, 0}, 0, tint)
}

@(private = "file")
scissor_start_rl :: proc(b: clay.BoundingBox) {
	rl.BeginScissorMode(
		i32(math.round(b.x)),
		i32(math.round(b.y)),
		i32(math.round(b.width)),
		i32(math.round(b.height)),
	)
}

@(private = "file")
scissor_end_rl :: proc() {
	rl.EndScissorMode()
}

@(private = "file")
to_render_color_rl :: #force_inline proc "contextless" (c: clay.Color) -> rl.Color {
	return {u8(c.r), u8(c.g), u8(c.b), u8(c.a)}
}

@(private = "file")
radius_px :: #force_inline proc "contextless" (r, w, h: f32) -> f32 {
	return min(r, min(w, h) * 0.5)
}

@(private = "file")
seg_for :: #force_inline proc "contextless" (rad: f32) -> i32 {
	return clamp(i32(rad * 0.5), 4, CORNER_SEGMENTS)
}

@(private = "file")
clamp_radii :: proc(tl, tr, bl, br, w, h: f32) -> (f32, f32, f32, f32) {
	tl, tr, bl, br := tl, tr, bl, br
	s := f32(1)
	if top := tl + tr; top > w do s = min(s, w / top)
	if bot := bl + br; bot > w do s = min(s, w / bot)
	if lft := tl + bl; lft > h do s = min(s, h / lft)
	if rgt := tr + br; rgt > h do s = min(s, h / rgt)
	if s < 1 {
		tl *= s
		tr *= s
		bl *= s
		br *= s
	}
	return tl, tr, bl, br
}

@(private = "file")
sector :: #force_inline proc(cx, cy, rad, start, end: f32, color: rl.Color) {
	if rad > 0 do rl.DrawCircleSector({cx, cy}, rad, start, end, seg_for(rad), color)
}

@(private = "file")
ring :: #force_inline proc(cx, cy, outer, width, start, end: f32, color: rl.Color) {
	if outer > 0 do rl.DrawRing({cx, cy}, max(outer - width, 0), outer, start, end, seg_for(outer), color)
}
