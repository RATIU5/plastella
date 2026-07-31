package gfx

import "../../vendor/clay"
import assets "../assets"
import platform "../platform"
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
VERTS_MAX :: 12 + 8 * SEGMENTS_MAX
INDICES_MAX :: 30 + 12 * SEGMENTS_MAX

// Exception to hidden global state: Used for dev tracing not a client-facing feature
@(private = "file")
had_error: bool

@(require_results)
clay_init :: proc(frame: ^Frame) -> (^clay.Context, [^]u8) {
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

clay_reload :: proc(ctx: ^clay.Context, asts: ^assets.Assets) {
	clay.SetCurrentContext(ctx)
	clay.SetMeasureTextFunction(measure_text, asts)
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
	context = runtime.default_context()
	a := cast(^assets.Assets)user_data
	assert(int(cfg.fontId) < len(a.fonts))
	font := a.fonts[assets.Text(cfg.fontId)]

	w, h: c.int
	if !ttf.GetStringSize(font, (cstring)(str.chars), uint(str.length), &w, &h) {
		sdl.LogError(i32(sdl.LogCategory.ERROR), "Failed to measure text: %s", sdl.GetError())
	}

	return {f32(w) / a.scale, f32(h) / a.scale}
}

clay_render_commands :: proc(commands: ^clay.ClayArray(clay.RenderCommand), frame: ^Frame) {
	sdl.SetRenderDrawBlendMode(frame.device.renderer, sdl.BLENDMODE_BLEND)

	for i in 0 ..< commands.length {
		cmd := clay.RenderCommandArray_Get(commands, i)
		b := cmd.boundingBox
		rect := sdl.FRect{f32(i32(b.x)), f32(i32(b.y)), f32(i32(b.width)), f32(i32(b.height))}

		#partial switch cmd.commandType {
		case .Rectangle:
			render_rectangle(frame.device.renderer, rect, cmd.renderData.rectangle)
		case .Text:
			render_text(frame, rect, cmd.renderData.text)
		case .Image:
			tex := (^sdl.Texture)(cmd.renderData.image.imageData)
			dst := rect
			sdl.RenderTexture(frame.device.renderer, tex, nil, &dst)
		case .Border:
			render_border(frame.device.renderer, rect, cmd.renderData.border)
		case .ScissorStart:
			clip := sdl.Rect{i32(b.x), i32(b.y), i32(b.width), i32(b.height)}
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
	rr := min(radius, min(rect.w, rect.h) / 2)
	segments := clamp(int(rr * 0.5), SEGMENTS_BASE, SEGMENTS_MAX)

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

@(private = "file")
render_border :: proc(renderer: ^sdl.Renderer, rect: sdl.FRect, cfg: clay.BorderRenderData) {
	min_radius := min(rect.w, rect.h) / 2
	tl := min(cfg.cornerRadius.topLeft, min_radius)
	tr := min(cfg.cornerRadius.topRight, min_radius)
	bl := min(cfg.cornerRadius.bottomLeft, min_radius)
	br := min(cfg.cornerRadius.bottomRight, min_radius)

	col := color_u8(cfg.color)
	sdl.SetRenderDrawColor(renderer, col.r, col.g, col.b, col.a)

	if cfg.width.left > 0 {
		line := sdl.FRect{rect.x - 1, rect.y, f32(cfg.width.left), rect.h - tr - bl}
		sdl.RenderFillRect(renderer, &line)
	}
	if cfg.width.right > 0 {
		x := rect.x + rect.w - f32(cfg.width.right) + 1
		line := sdl.FRect{x, rect.y + tr, f32(cfg.width.right), rect.h - tr - br}
		sdl.RenderFillRect(renderer, &line)
	}
	if cfg.width.top > 0 {
		line := sdl.FRect{rect.x + tl, rect.y - 1, rect.w - tl - tr, f32(cfg.width.top)}
		sdl.RenderFillRect(renderer, &line)
	}
	if cfg.width.bottom > 0 {
		y := rect.y + rect.h - f32(cfg.width.bottom) + 1
		line := sdl.FRect{rect.x + bl, y, rect.w - bl - br, f32(cfg.width.bottom)}
		sdl.RenderFillRect(renderer, &line)
	}

	// Rounded corners as stroked arcs, thickness from nearer edge.
	if cfg.cornerRadius.topLeft > 0 {
		center := sdl.FPoint{rect.x + tl - 1, rect.y + tl - 1}
		render_arc(renderer, center, tl, 180, 270, f32(cfg.width.top), cfg.color)
	}
}

@(private = "file")
render_text :: proc(frame: ^Frame, rect: sdl.FRect, cfg: clay.TextRenderData) {
	assert(int(cfg.fontId) < len(frame.assets.fonts))
	font := frame.assets.fonts[assets.Text(cfg.fontId)]

	d := frame.assets.scale
	sdl.SetRenderScale(frame.device.renderer, 1, 1) // Set render scale for this text

	chars := cast(cstring)cfg.stringContents.chars
	text := ttf.CreateText(
		frame.device.text_engine,
		font,
		chars,
		c.size_t(cfg.stringContents.length),
	)
	defer ttf.DestroyText(text)

	col := color_u8(cfg.textColor)
	ttf.SetTextColor(text, col.r, col.g, col.b, col.a)
	ttf.DrawRendererText(text, rect.x * d, rect.y * d)

	sdl.SetRenderScale(frame.device.renderer, d, d) // Unset render scale for new renders
}

@(private = "file")
render_arc :: proc(
	renderer: ^sdl.Renderer,
	center: sdl.FPoint,
	radius, start_deg, end_deg, thickness: f32,
	color: clay.Color,
) {
	col := color_u8(color)
	sdl.SetRenderDrawColor(renderer, col.r, col.g, col.b, col.a)

	rad_start := start_deg * (math.PI / 180)
	rad_end := end_deg * (math.PI / 180)
	segments := clamp(int(radius * 1.5), SEGMENTS_BASE, ARC_SEGMENTS_MAX)
	angle_step := (rad_end - rad_start) / f32(segments)

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
		sdl.RenderLines(renderer, raw_data(points[:]), c.int(segments + 1))
	}
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
err_handler :: proc "c" (err: clay.ErrorData) {
	context = runtime.default_context()
	had_error = true

	msg := cast(string)(err.errorText.chars)[:err.errorText.length]
	err := fmt.tprintf("[clay] %v: %s\n", err.errorType, msg)

	when ODIN_DEBUG {
		panic(err)
	} else {
		fmt.eprintln(err)
	}
}


// Keep SDL texture package loaded for texture rendering
_ :: img.LoadTexture
