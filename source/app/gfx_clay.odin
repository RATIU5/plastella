package app

import "../../vendor/clay"
import "../platform"
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:math"
import sdl "vendor:sdl3"
import img "vendor:sdl3/image"
import "vendor:sdl3/ttf"

SEGMENTS_BASE :: 16
SEGMENTS_MAX :: 32
ARC_SEGMENTS_MAX :: 32

// --- Curve antialiasing tuning: device pixels, tweak by eye and rebuild. ---

// Feather width: curved edges fade to transparent over this distance instead
// of hard-cutting. Larger = softer/blurrier. Flat edges stay sharp.
FEATHER_PX :: 1.0

// Feather never eats more than this fraction of the thickness/radius it's
// carving into, so a thin stroke keeps a solid opaque core (see feather_clamp).
FEATHER_CORE_FRACTION :: 0.25

// Nudges the curve's radius outward so it lines up with the straight edges
// it's tangent to (RenderGeometry rasterizes coverage a hair inside RenderFillRect's).
BOUNDARY_BIAS_PX :: 0.45

// Fraction of each curve's segments, at each end, that eases back to opaque so
// a feather band meets a straight unfeathered edge smoothly, not with a snap.
SEAM_TAPER_FRACTION :: 0.2

// fill_rounded_rect buffer sizes: fixed geometry + per-corner fan + feather band.
VERTS_MAX :: 12 + 8 * SEGMENTS_MAX + 4 * 2 * (SEGMENTS_MAX + 1)
INDICES_MAX :: 30 + 12 * SEGMENTS_MAX + 4 * 6 * SEGMENTS_MAX

// Exception to hidden global state: Used for dev tracing not a client-facing feature
@(private = "file")
had_error: bool

// Built once at init so measure_text does not construct a Context on every call.
// clay invokes it many times per layout. File-scope because it must be re-set after a hot reload.
@(private = "file")
measure_ctx: runtime.Context

@(require_results)
clay_init :: proc(frame: ^Frame) -> (^clay.Context, [^]u8) {
	measure_ctx = context
	min_size := clay.MinMemorySize()
	clay_mem := make([^]u8, min_size)
	arena := clay.CreateArenaWithCapacityAndMemory(cast(c.size_t)min_size, clay_mem)

	ctx := clay.Initialize(
		arena,
		{f32(frame.screen.x), f32(frame.screen.y)},
		{handler = err_handler, userData = &had_error},
	)

	if ctx == nil || had_error {
		fmt.eprintln("[clay] initalization failed\n")
		if clay_mem != nil {
			free(clay_mem)
		}
		return nil, nil
	}

	clay.SetMeasureTextFunction(measure_text, frame.assets)

	return ctx, clay_mem
}

@(require_results)
clay_reload :: proc(gfx: ^Gfx, asts: ^Assets, screen: [2]f32) -> bool {
	measure_ctx = context

	size := clay.MinMemorySize()
	if size != gfx.clay_mem_size {
		fmt.eprintfln(
			"[clay] arena size changed %d -> %d; restart required (F6)",
			gfx.clay_mem_size,
			size,
		)
		return false
	}

	had_error = false
	arena := clay.CreateArenaWithCapacityAndMemory(c.size_t(size), gfx.clay_mem)
	ctx := clay.Initialize(
		arena,
		{screen.x, screen.y},
		{handler = err_handler, userData = nil}, // handler reads the file global directly
	)
	if ctx == nil || had_error do return false

	gfx.clay_ctx = ctx
	clay.SetMeasureTextFunction(measure_text, asts)
	return true
}

clay_frame_begin :: proc(frame: ^Frame) {
	had_error = false
	clay.SetLayoutDimensions({width = frame.screen.x, height = frame.screen.y})
	clay.SetPointerState(frame.input.mouse.pos, platform.mouse_pressed(frame.input, .Left))
	clay.UpdateScrollContainers(true, frame.input.mouse.wheel, frame.dt)
	clay.BeginLayout()
}

clay_frame_end :: proc(frame: ^Frame) {
	commands := clay.EndLayout(frame.dt)
	clay_render_commands(&commands, frame)
}

clay_shutdown :: proc(gfx: ^Gfx) {
	free(gfx.clay_mem)
}

measure_text :: proc "c" (
	str: clay.StringSlice,
	cfg: ^clay.TextElementConfig,
	user_data: rawptr,
) -> clay.Dimensions {
	context = measure_ctx
	a := cast(^Assets)user_data
	assert(int(cfg.fontId) < len(a.fonts))
	font := a.fonts[Text(cfg.fontId)]

	// SDL_ttf treats length == 0 as "use the NUL-terminated length of text"
	// instead of "the string is empty". str.chars here can point into a
	// strings.Builder's backing buffer, which is never NUL-terminated and
	// isn't zeroed on reset/remove - GetStringSize would read past the
	// logical end into unrelated memory. Skip the call; the answer is 0 width.
	if str.length == 0 {
		return {0, f32(ttf.GetFontHeight(font)) / a.scale}
	}

	w, h: c.int
	if !ttf.GetStringSize(font, (cstring)(str.chars), uint(str.length), &w, &h) {
		sdl.LogError(i32(sdl.LogCategory.ERROR), "Failed to measure text: %s", sdl.GetError())
	}

	return {f32(w) / a.scale, f32(h) / a.scale}
}

clay_render_commands :: proc(commands: ^clay.ClayArray(clay.RenderCommand), frame: ^Frame) {
	d := frame.assets.scale
	sdl.SetRenderDrawBlendMode(frame.device.renderer, sdl.BLENDMODE_BLEND)

	for i in 0 ..< commands.length {
		cmd := clay.RenderCommandArray_Get(commands, i)
		b := cmd.boundingBox
		rect := sdl.FRect {
			math.round(b.x * d),
			math.round(b.y * d),
			math.round(b.width * d),
			math.round(b.height * d),
		}

		switch cmd.commandType {
		case .Rectangle:
			cfg := cmd.renderData.rectangle
			cfg.cornerRadius = scale_radius(cfg.cornerRadius, d)
			render_rectangle(frame.device.renderer, rect, cfg)
		case .Text:
			render_text(rect, cmd.renderData.text, frame)
		case .Image:
			slice := (^Texture_Slice)(cmd.renderData.image.imageData)
			dst := rect
			src: sdl.FRect
			sdl.RectToFRect(slice.crop, &src)
			tint := color_u8(clay.Color(slice.tint))
			sdl.SetTextureColorMod(slice.tex, tint.r, tint.g, tint.b)
			sdl.SetTextureAlphaMod(slice.tex, tint.a)
			sdl.RenderTexture(frame.device.renderer, slice.tex, &src, &dst)
		case .Border:
			cfg := cmd.renderData.border
			cfg.cornerRadius = scale_radius(cfg.cornerRadius, d)
			cfg.width = scale_border_width(cfg.width, d)
			render_border(frame.device.renderer, rect, cfg)
		case .ScissorStart:
			clip := sdl.Rect{i32(rect.x), i32(rect.y), i32(rect.w), i32(rect.h)}
			sdl.SetRenderClipRect(frame.device.renderer, &clip)
		case .ScissorEnd:
			sdl.SetRenderClipRect(frame.device.renderer, nil)
		case .None, .Custom, .OverlayColorStart, .OverlayColorEnd:
		// Not implemented
		}
	}
}

@(private = "file")
render_rectangle :: proc(renderer: ^sdl.Renderer, rect: sdl.FRect, cfg: clay.RectangleRenderData) {
	if cfg.cornerRadius.topLeft > 0 {
		fill_rounded_rect(renderer, rect, cfg.cornerRadius.topLeft, cfg.backgroundColor)
		return
	}
	col := color_u8(cfg.backgroundColor)
	sdl.SetRenderDrawColor(renderer, col.r, col.g, col.b, col.a)
	r := rect
	sdl.RenderFillRect(renderer, &r)
}

@(private = "file")
fill_rounded_rect :: proc(
	renderer: ^sdl.Renderer,
	rect: sdl.FRect,
	radius: f32,
	color: clay.Color,
) {
	fc := color_float(color)
	fc_clear := fc
	fc_clear.a = 0
	rr := min(radius, min(rect.w, rect.h) / 2)
	rr_curve := rr + BOUNDARY_BIAS_PX
	// Feather is carved out of the fan (stops at rr_core), not added past rr_curve,
	// so the corner's outer radius matches the straight sides it's tangent to.
	rr_core := max(rr_curve - feather_clamp(rr_curve), 0)
	segments := clamp(int(rr * 0.5), SEGMENTS_BASE, SEGMENTS_MAX)
	assert(segments <= SEGMENTS_MAX)

	verts: [VERTS_MAX]sdl.Vertex = ---
	indices: [INDICES_MAX]c.int = ---

	verts[0] = {{rect.x + rr, rect.y + rr}, fc, {0, 0}}
	verts[1] = {{rect.x + rect.w - rr, rect.y + rr}, fc, {0, 0}}
	verts[2] = {{rect.x + rect.w - rr, rect.y + rect.h - rr}, fc, {0, 0}}
	verts[3] = {{rect.x + rr, rect.y + rect.h - rr}, fc, {0, 0}}
	vc := 4

	indices[0], indices[1], indices[2] = 0, 1, 3
	indices[3], indices[4], indices[5] = 1, 2, 3
	ic := 6

	corners := [4]struct {
		cx, cy, sx, sy: f32,
	} {
		{rect.x + rr, rect.y + rr, -1, -1}, // top-left, center vertex 0
		{rect.x + rect.w - rr, rect.y + rr, 1, -1}, // top-right, center vertex 1
		{rect.x + rect.w - rr, rect.y + rect.h - rr, 1, 1}, // bot-right, center vertex 2
		{rect.x + rr, rect.y + rect.h - rr, -1, 1}, // bot-left, center vertex 3
	}

	step := (math.PI * 0.5) / f32(segments)
	for i in 0 ..< segments {
		a1 := f32(i) * step
		a2 := f32(i + 1) * step
		for corner, j in corners {
			p1 := sdl.FPoint {
				corner.cx + math.cos(a1) * rr_core * corner.sx,
				corner.cy + math.sin(a1) * rr_core * corner.sy,
			}
			p2 := sdl.FPoint {
				corner.cx + math.cos(a2) * rr_core * corner.sx,
				corner.cy + math.sin(a2) * rr_core * corner.sy,
			}
			verts[vc] = {p1, fc, {0, 0}}
			verts[vc + 1] = {p2, fc, {0, 0}}
			indices[ic], indices[ic + 1], indices[ic + 2] = c.int(j), c.int(vc), c.int(vc + 1)
			vc += 2
			ic += 3
		}
	}

	// Feather ring per corner, rr_core (opaque) to rr_curve (transparent).
	// Degrees match `corners`' order (TL, TR, BR, BL), y grows downward.
	feather_ranges := [4][2]f32{{180, 270}, {270, 360}, {0, 90}, {90, 180}}
	for corner, j in corners {
		lo := feather_ranges[j][0] * (math.PI / 180)
		hi := feather_ranges[j][1] * (math.PI / 180)
		emit_ring_band(
			verts[:],
			indices[:],
			&vc,
			&ic,
			{corner.cx, corner.cy},
			rr_curve,
			rr_core,
			fc_clear,
			fc,
			lo,
			hi,
			segments,
		)
	}

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

	sdl.RenderGeometry(
		renderer,
		nil,
		raw_data(verts[:]),
		c.int(vc),
		raw_data(indices[:]),
		c.int(ic),
	)
}

// Caps the feather to a fraction of `extent` so a thin stroke or small radius
// keeps a solid opaque core instead of the feather consuming all of it.
@(private = "file")
feather_clamp :: proc "contextless" (extent: f32) -> f32 {
	return min(FEATHER_PX, extent * FEATHER_CORE_FRACTION)
}

// Emits one ring of quads between two concentric arcs, from rad_start to
// rad_end, into verts/indices at *vc/*ic. Shared by opaque and feather bands.
@(private = "file")
emit_ring_band :: proc(
	verts: []sdl.Vertex,
	indices: []c.int,
	vc, ic: ^int,
	center: sdl.FPoint,
	r_outer, r_inner: f32,
	color_outer, color_inner: sdl.FColor,
	rad_start, rad_end: f32,
	segments: int,
) {
	// Eases the faded side back toward opaque near each end (SEAM_TAPER_FRACTION).
	// No-op on the opaque core band, where both colors already share one alpha.
	taper_segments := max(1, min(segments / 2, int(f32(segments) * SEAM_TAPER_FRACTION)))
	opaque_alpha := max(color_outer.a, color_inner.a)

	angle_step := (rad_end - rad_start) / f32(segments)
	for i in 0 ..= segments {
		angle := rad_start + f32(i) * angle_step
		cos, sin := math.cos(angle), math.sin(angle)

		t := f32(1)
		if i < taper_segments {
			t = f32(i) / f32(taper_segments)
		} else if i > segments - taper_segments {
			t = f32(segments - i) / f32(taper_segments)
		}
		co, ci := color_outer, color_inner
		co.a = opaque_alpha + (color_outer.a - opaque_alpha) * t
		ci.a = opaque_alpha + (color_inner.a - opaque_alpha) * t

		verts[vc^] = {{center.x + cos * r_outer, center.y + sin * r_outer}, co, {0, 0}}
		verts[vc^ + 1] = {{center.x + cos * r_inner, center.y + sin * r_inner}, ci, {0, 0}}
		if i < segments {
			o0, i0 := c.int(vc^), c.int(vc^ + 1)
			o1, i1 := c.int(vc^ + 2), c.int(vc^ + 3)
			indices[ic^], indices[ic^ + 1], indices[ic^ + 2] = o0, o1, i0
			indices[ic^ + 3], indices[ic^ + 4], indices[ic^ + 5] = o1, i1, i0
			ic^ += 6
		}
		vc^ += 2
	}
}

@(private = "file")
Border_Corner :: struct {
	radius:    f32,
	center:    sdl.FPoint,
	start_deg: f32,
	end_deg:   f32,
	thickness: f32,
}

@(private = "file")
render_border :: proc(renderer: ^sdl.Renderer, rect: sdl.FRect, cfg: clay.BorderRenderData) {
	col := color_u8(cfg.color)
	sdl.SetRenderDrawColor(renderer, col.r, col.g, col.b, col.a)

	// Clamp so two radii on the same axis cannot overlap and produce a negative run.
	r_max := min(rect.w, rect.h) / 2
	tl := min(cfg.cornerRadius.topLeft, r_max)
	tr := min(cfg.cornerRadius.topRight, r_max)
	br := min(cfg.cornerRadius.bottomRight, r_max)
	bl := min(cfg.cornerRadius.bottomLeft, r_max)

	w := cfg.width

	// Straight runs sit flush inside the rect and are shortened by the two radii on
	// their own axis.
	if w.top > 0 {
		side := sdl.FRect{rect.x + tl, rect.y, rect.w - tl - tr, f32(w.top)}
		sdl.RenderFillRect(renderer, &side)
	}
	if w.bottom > 0 {
		y := rect.y + rect.h - f32(w.bottom)
		side := sdl.FRect{rect.x + bl, y, rect.w - bl - br, f32(w.bottom)}
		sdl.RenderFillRect(renderer, &side)
	}
	if w.left > 0 {
		side := sdl.FRect{rect.x, rect.y + tl, f32(w.left), rect.h - tl - bl}
		sdl.RenderFillRect(renderer, &side)
	}
	if w.right > 0 {
		x := rect.x + rect.w - f32(w.right)
		side := sdl.FRect{x, rect.y + tr, f32(w.right), rect.h - tr - br}
		sdl.RenderFillRect(renderer, &side)
	}

	// Angles are SDL screen space (y down), so 180-270 sweeps top-left.
	// Thickness takes the wider adjacent side so a corner never reads thinner.
	corners := [4]Border_Corner {
		{tl, {rect.x + tl, rect.y + tl}, 180, 270, f32(max(w.top, w.left))},
		{tr, {rect.x + rect.w - tr, rect.y + tr}, 270, 360, f32(max(w.top, w.right))},
		{br, {rect.x + rect.w - br, rect.y + rect.h - br}, 0, 90, f32(max(w.bottom, w.right))},
		{bl, {rect.x + bl, rect.y + rect.h - bl}, 90, 180, f32(max(w.bottom, w.left))},
	}

	for c in corners {
		if c.radius <= 0 do continue
		if c.thickness <= 0 do continue
		render_arc(renderer, c.center, c.radius, c.start_deg, c.end_deg, c.thickness, cfg.color)
	}
}

@(private = "file")
render_text :: proc(rect: sdl.FRect, cfg: clay.TextRenderData, frame: ^Frame) {
	assert(int(cfg.fontId) < len(frame.assets.fonts))

	chars := ([^]u8)(cfg.stringContents.chars)
	str := string(chars[:cfg.stringContents.length])
	text := text_cache_get(
		&frame.gfx.text_cache,
		frame.device,
		frame.assets,
		str,
		Text(cfg.fontId),
	)
	if text == nil do return

	col := color_u8(cfg.textColor)
	ttf.SetTextColor(text, col.r, col.g, col.b, col.a)
	ttf.DrawRendererText(text, rect.x, rect.y)
}

@(private = "file")
render_arc :: proc(
	renderer: ^sdl.Renderer,
	center: sdl.FPoint,
	radius, start_deg, end_deg, thickness: f32,
	color: clay.Color,
) {
	// Fills a quarter-annulus as geometry so it joins the straight border runs
	// with no seam. (Old approach: stacked polylines staircased on the pixel grid.)
	fc := color_float(color)
	fc_clear := fc
	fc_clear.a = 0
	r_out := radius
	r_out_curve := r_out + BOUNDARY_BIAS_PX // matches the straight border runs; see BOUNDARY_BIAS_PX.
	r_in := max(radius - thickness, 0) // inner ring lands on the straight-edge inner boundary.

	rad_start := start_deg * (math.PI / 180)
	rad_end := end_deg * (math.PI / 180)
	segments := clamp(int(radius * 1.5), SEGMENTS_BASE, ARC_SEGMENTS_MAX)
	assert(segments <= ARC_SEGMENTS_MAX) // buffers below are sized for exactly this, checked before the first write.

	// Feather is carved out of [r_in, r_out], not added past it, so the stroke's
	// radius matches the straight runs. r_in_core only applies when r_in > 0.
	feather := feather_clamp(thickness)
	r_out_core := max(r_out_curve - feather, r_in)
	r_in_core := r_in
	if r_in > 0 {
		r_in_core = min(r_in + feather, r_out_curve)
	}
	if r_in_core > r_out_core do r_in_core = r_out_core

	// Opaque core plus a feather on each curved edge. End caps stay sharp on
	// purpose — they butt against the straight border runs.
	verts: [(ARC_SEGMENTS_MAX + 1) * 2 * 3]sdl.Vertex = ---
	indices: [ARC_SEGMENTS_MAX * 6 * 3]c.int = ---
	vc, ic := 0, 0

	if r_out_core > r_in_core {
		emit_ring_band(
			verts[:],
			indices[:],
			&vc,
			&ic,
			center,
			r_out_core,
			r_in_core,
			fc,
			fc,
			rad_start,
			rad_end,
			segments,
		)
	}
	emit_ring_band(
		verts[:],
		indices[:],
		&vc,
		&ic,
		center,
		r_out_curve,
		r_out_core,
		fc_clear,
		fc,
		rad_start,
		rad_end,
		segments,
	)
	if r_in > 0 && r_in_core > r_in {
		emit_ring_band(
			verts[:],
			indices[:],
			&vc,
			&ic,
			center,
			r_in_core,
			r_in,
			fc,
			fc_clear,
			rad_start,
			rad_end,
			segments,
		)
	}

	sdl.RenderGeometry(
		renderer,
		nil,
		raw_data(verts[:]),
		c.int(vc),
		raw_data(indices[:]),
		c.int(ic),
	)
}

@(private = "file")
color_float :: proc "contextless" (col: clay.Color) -> sdl.FColor {
	return {col.r / 255, col.g / 255, col.b / 255, col.a / 255}
}

@(private = "file")
color_u8 :: proc "contextless" (col: clay.Color) -> [4]u8 {
	return {u8(col.r), u8(col.g), u8(col.b), u8(col.a)}
}

@(private = "file")
scale_radius :: proc "contextless" (r: clay.CornerRadius, d: f32) -> clay.CornerRadius {
	return {r.topLeft * d, r.topRight * d, r.bottomLeft * d, r.bottomRight * d}
}

@(private = "file")
scale_width :: proc "contextless" (v: u16, d: f32) -> u16 {
	if v == 0 do return 0
	return u16(max(math.round(f32(v) * d), 1))
}

@(private = "file")
scale_border_width :: proc "contextless" (w: clay.BorderWidth, d: f32) -> clay.BorderWidth {
	return {
		left = scale_width(w.left, d),
		right = scale_width(w.right, d),
		top = scale_width(w.top, d),
		bottom = scale_width(w.bottom, d),
		betweenChildren = scale_width(w.betweenChildren, d),
	}
}

@(private = "file")
err_handler :: proc "c" (err: clay.ErrorData) {
	context = runtime.default_context()
	had_error = true

	msg := cast(string)(err.errorText.chars)[:err.errorText.length]
	msg_full := fmt.tprintf("[clay] %v: %s\n", err.errorType, msg)

	when ODIN_DEBUG {
		panic(msg_full)
	} else {
		fmt.eprintln(msg_full)
	}
}


// Keep SDL texture package loaded for texture rendering
_ :: img.LoadTexture
