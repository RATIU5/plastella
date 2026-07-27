package gfx

import clay "../../vendor/clay"
import "core:c"
import "core:math"
import sdl "vendor:sdl3"
import img "vendor:sdl3/image"
import ttf "vendor:sdl3/ttf"

// Base segment count per quarter-circle. Enough for smooth curves at typical UI radii; a
// large radius on a hi-dpi surface scales up toward SEGMENTS_MAX (see fill_rounded_rect).
SEGMENTS_BASE :: 16
// The C reference sizes its vertex buffer with a stack VLA, i.e. an unbounded stack alloc.
// We cap segments instead (style 2.2) so the vertex/index buffers are fixed and provable.
SEGMENTS_MAX :: 32
ARC_SEGMENTS_MAX :: 64

// Worst-case geometry for one rounded rect at SEGMENTS_MAX:
//   verts = 4 center + 4 corners*(seg*2) + 2*4 edge = 12 + 8*seg
//   idx   = 6 center + 4 corners*(seg*3) + 6*4 edge = 30 + 12*seg
VERTS_MAX :: 12 + 8 * SEGMENTS_MAX
INDICES_MAX :: 30 + 12 * SEGMENTS_MAX

// Everything the renderer needs to turn a clay command array into SDL draw calls. The caller
// owns these handles and their lifetimes; the renderer only borrows them (style 3.5, 2.5).
Renderer_Data :: struct {
	renderer:    ^sdl.Renderer,
	text_engine: ^ttf.TextEngine,
	fonts:       []^ttf.Font, // indexed by clay's fontId
}

/*
Draws one frame of clay render commands into the SDL renderer.

Assumes the caller has already cleared the target and will present afterward. Text commands
resize the font in `data.fonts[fontId]` in place, so fonts are shared, not reentrant.

Inputs:
- data:     renderer handles, borrowed for the call
- commands: clay's per-frame command array, produced by clay.EndLayout
*/
render_clay_commands :: proc(data: ^Renderer_Data, commands: ^clay.ClayArray(clay.RenderCommand)) {
	assert(data != nil)
	assert(data.renderer != nil)

	// Alpha blending is a render state, so set it once rather than per rectangle.
	sdl.SetRenderDrawBlendMode(data.renderer, sdl.BLENDMODE_BLEND)

	for i in 0 ..< commands.length {
		cmd := clay.RenderCommandArray_Get(commands, i)
		b := cmd.boundingBox
		// Floor to whole pixels to match the C reference and avoid subpixel seams.
		rect := sdl.FRect{f32(i32(b.x)), f32(i32(b.y)), f32(i32(b.width)), f32(i32(b.height))}

		switch cmd.commandType {
		case .Rectangle:
			render_rectangle(data, rect, cmd.renderData.rectangle)
		case .Text:
			render_text(data, rect, cmd.renderData.text)
		case .Image:
			tex := (^sdl.Texture)(cmd.renderData.image.imageData)
			dst := rect
			sdl.RenderTexture(data.renderer, tex, nil, &dst)
		case .Border:
			render_border(data, rect, cmd.renderData.border)
		case .ScissorStart:
			clip := sdl.Rect{i32(b.x), i32(b.y), i32(b.width), i32(b.height)}
			sdl.SetRenderClipRect(data.renderer, &clip)
		case .ScissorEnd:
			sdl.SetRenderClipRect(data.renderer, nil)
		case .None, .Custom, .OverlayColorStart, .OverlayColorEnd:
		// Not produced by this app yet.
		}
	}
}

@(private = "file")
render_rectangle :: proc(data: ^Renderer_Data, rect: sdl.FRect, cfg: clay.RectangleRenderData) {
	// The C reference treats topLeft as the single uniform radius; follow it.
	if cfg.cornerRadius.topLeft > 0 {
		fill_rounded_rect(data, rect, cfg.cornerRadius.topLeft, cfg.backgroundColor)
		return
	}
	col := color_u8(cfg.backgroundColor)
	sdl.SetRenderDrawColor(data.renderer, col.r, col.g, col.b, col.a)
	r := rect
	sdl.RenderFillRect(data.renderer, &r)
}

@(private = "file")
render_text :: proc(data: ^Renderer_Data, rect: sdl.FRect, cfg: clay.TextRenderData) {
	assert(int(cfg.fontId) < len(data.fonts))
	font := data.fonts[cfg.fontId]

	ttf.SetFontSize(font, f32(cfg.fontSize))

	// length is given, so SDL never reads past the (non-terminated) clay slice.
	chars := cast(cstring)cfg.stringContents.chars
	text := ttf.CreateText(data.text_engine, font, chars, c.size_t(cfg.stringContents.length))
	defer ttf.DestroyText(text)

	col := color_u8(cfg.textColor)
	ttf.SetTextColor(text, col.r, col.g, col.b, col.a)
	ttf.DrawRendererText(text, rect.x, rect.y)
}

@(private = "file")
render_border :: proc(data: ^Renderer_Data, rect: sdl.FRect, cfg: clay.BorderRenderData) {
	min_radius := min(rect.w, rect.h) / 2
	tl := min(cfg.cornerRadius.topLeft, min_radius)
	tr := min(cfg.cornerRadius.topRight, min_radius)
	bl := min(cfg.cornerRadius.bottomLeft, min_radius)
	br := min(cfg.cornerRadius.bottomRight, min_radius)

	col := color_u8(cfg.color)
	sdl.SetRenderDrawColor(data.renderer, col.r, col.g, col.b, col.a)

	// Straight edges, each inset by its two adjacent corner radii. The -1/+1 nudges mirror
	// the C reference so edges meet the arcs without a gap.
	if cfg.width.left > 0 {
		line := sdl.FRect{rect.x - 1, rect.y + tl, f32(cfg.width.left), rect.h - tl - bl}
		sdl.RenderFillRect(data.renderer, &line)
	}
	if cfg.width.right > 0 {
		x := rect.x + rect.w - f32(cfg.width.right) + 1
		line := sdl.FRect{x, rect.y + tr, f32(cfg.width.right), rect.h - tr - br}
		sdl.RenderFillRect(data.renderer, &line)
	}
	if cfg.width.top > 0 {
		line := sdl.FRect{rect.x + tl, rect.y - 1, rect.w - tl - tr, f32(cfg.width.top)}
		sdl.RenderFillRect(data.renderer, &line)
	}
	if cfg.width.bottom > 0 {
		y := rect.y + rect.h - f32(cfg.width.bottom) + 1
		line := sdl.FRect{rect.x + bl, y, rect.w - bl - br, f32(cfg.width.bottom)}
		sdl.RenderFillRect(data.renderer, &line)
	}

	// Rounded corners as stroked arcs, thickness taken from the nearer edge.
	if cfg.cornerRadius.topLeft > 0 {
		center := sdl.FPoint{rect.x + tl - 1, rect.y + tl - 1}
		render_arc(data, center, tl, 180, 270, f32(cfg.width.top), cfg.color)
	}
	if cfg.cornerRadius.topRight > 0 {
		center := sdl.FPoint{rect.x + rect.w - tr, rect.y + tr - 1}
		render_arc(data, center, tr, 270, 360, f32(cfg.width.top), cfg.color)
	}
	if cfg.cornerRadius.bottomLeft > 0 {
		center := sdl.FPoint{rect.x + bl - 1, rect.y + rect.h - bl}
		render_arc(data, center, bl, 90, 180, f32(cfg.width.bottom), cfg.color)
	}
	if cfg.cornerRadius.bottomRight > 0 {
		center := sdl.FPoint{rect.x + rect.w - br, rect.y + rect.h - br}
		render_arc(data, center, br, 0, 90, f32(cfg.width.bottom), cfg.color)
	}
}

// Fills a uniform-radius rounded rectangle in a single RenderGeometry call: a center quad,
// four triangle-fan corners, and four edge quads that reuse the center's corner vertices.
@(private = "file")
fill_rounded_rect :: proc(data: ^Renderer_Data, rect: sdl.FRect, radius: f32, color: clay.Color) {
	fc := color_float(color)
	rr := min(radius, min(rect.w, rect.h) / 2)
	segments := clamp(int(rr * 0.5), SEGMENTS_BASE, SEGMENTS_MAX)

	verts: [VERTS_MAX]sdl.Vertex = ---
	indices: [INDICES_MAX]c.int = ---

	// Center quad. Its four vertices (0..3) are shared by the corner fans and edge quads.
	verts[0] = {{rect.x + rr, rect.y + rr}, fc, {0, 0}}
	verts[1] = {{rect.x + rect.w - rr, rect.y + rr}, fc, {0, 0}}
	verts[2] = {{rect.x + rect.w - rr, rect.y + rect.h - rr}, fc, {0, 0}}
	verts[3] = {{rect.x + rr, rect.y + rect.h - rr}, fc, {0, 0}}
	vc := 4
	indices[0], indices[1], indices[2] = 0, 1, 3
	indices[3], indices[4], indices[5] = 1, 2, 3
	ic := 6

	// Corner centers and unit-direction signs, paired with the center vertex they fan around.
	corners := [4]struct {
		cx, cy, sx, sy: f32,
	} {
		{rect.x + rr, rect.y + rr, -1, -1}, // top-left,  center vertex 0
		{rect.x + rect.w - rr, rect.y + rr, 1, -1}, // top-right, center vertex 1
		{rect.x + rect.w - rr, rect.y + rect.h - rr, 1, 1}, // bot-right, center vertex 2
		{rect.x + rr, rect.y + rect.h - rr, -1, 1}, // bot-left,  center vertex 3
	}

	step := (math.PI * 0.5) / f32(segments)
	for i in 0 ..< segments {
		a1 := f32(i) * step
		a2 := f32(i + 1) * step
		for corner, j in corners {
			p1 := sdl.FPoint {
				corner.cx + math.cos(a1) * rr * corner.sx,
				corner.cy + math.sin(a1) * rr * corner.sy,
			}
			p2 := sdl.FPoint {
				corner.cx + math.cos(a2) * rr * corner.sx,
				corner.cy + math.sin(a2) * rr * corner.sy,
			}
			verts[vc] = {p1, fc, {0, 0}}
			verts[vc + 1] = {p2, fc, {0, 0}}
			indices[ic], indices[ic + 1], indices[ic + 2] = c.int(j), c.int(vc), c.int(vc + 1)
			vc += 2
			ic += 3
		}
	}

	// Edge quads: two outer vertices per edge, triangulated against two shared center vertices.
	edges := [4]struct {
		p0, p1: sdl.FPoint,
		c0, c1: c.int,
	} {
		{{rect.x + rr, rect.y}, {rect.x + rect.w - rr, rect.y}, 0, 1}, // top
		{{rect.x + rect.w, rect.y + rr}, {rect.x + rect.w, rect.y + rect.h - rr}, 1, 2}, // right
		{{rect.x + rect.w - rr, rect.y + rect.h}, {rect.x + rr, rect.y + rect.h}, 2, 3}, // bottom
		{{rect.x, rect.y + rect.h - rr}, {rect.x, rect.y + rr}, 3, 0}, // left
	}
	for e in edges {
		v0, v1 := c.int(vc), c.int(vc + 1)
		verts[vc] = {e.p0, fc, {0, 0}}
		verts[vc + 1] = {e.p1, fc, {0, 0}}
		indices[ic], indices[ic + 1], indices[ic + 2] = e.c0, v0, v1
		indices[ic + 3], indices[ic + 4], indices[ic + 5] = e.c1, e.c0, v1
		vc += 2
		ic += 6
	}

	assert(vc <= VERTS_MAX) // fixed cap holds because segments <= SEGMENTS_MAX
	assert(ic <= INDICES_MAX)
	sdl.RenderGeometry(data.renderer, nil, raw_data(verts[:]), c.int(vc), raw_data(indices[:]), c.int(ic))
}

// Strokes a quarter-arc as concentric line strips, one per thickness step, matching the C
// reference. Thickness is a small border width, so both loops are tightly bounded.
@(private = "file")
render_arc :: proc(
	data: ^Renderer_Data,
	center: sdl.FPoint,
	radius, start_deg, end_deg, thickness: f32,
	color: clay.Color,
) {
	col := color_u8(color)
	sdl.SetRenderDrawColor(data.renderer, col.r, col.g, col.b, col.a)

	rad_start := start_deg * (math.PI / 180)
	rad_end := end_deg * (math.PI / 180)
	segments := clamp(int(radius * 1.5), SEGMENTS_BASE, ARC_SEGMENTS_MAX)
	angle_step := (rad_end - rad_start) / f32(segments)

	// Arbitrary step that avoids overlapping strips; smaller values just draw more lines.
	THICKNESS_STEP :: f32(0.4)

	points: [ARC_SEGMENTS_MAX + 1]sdl.FPoint = ---
	for t := THICKNESS_STEP; t < thickness - THICKNESS_STEP; t += THICKNESS_STEP {
		r := max(radius - t, 1)
		for i in 0 ..= segments {
			angle := rad_start + f32(i) * angle_step
			points[i] = {
				math.round(center.x + math.cos(angle) * r),
				math.round(center.y + math.sin(angle) * r),
			}
		}
		sdl.RenderLines(data.renderer, raw_data(points[:]), c.int(segments + 1))
	}
}

// clay colors are f32 in 0..255; SDL float colors are 0..1.
@(private = "file")
color_float :: proc "contextless" (col: clay.Color) -> sdl.FColor {
	return {col.r / 255, col.g / 255, col.b / 255, col.a / 255}
}

@(private = "file")
color_u8 :: proc "contextless" (col: clay.Color) -> [4]u8 {
	return {u8(col.r), u8(col.g), u8(col.b), u8(col.a)}
}

// Keep the SDL_image import live; texture loading lives with asset code, not the renderer.
_ :: img.LoadTexture
