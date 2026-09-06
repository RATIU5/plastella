package app

import "../../vendor/clay"
import "../platform"
import "core:math"
import "core:strconv"
import "core:strings"
import sdl "vendor:sdl3"

Number_Format :: #type proc(value: f32, buf: []u8) -> string

Number_Step :: #type proc(value: f32, dir: int) -> f32

Number_Opts :: struct {
	step:      f32,
	step_proc: Number_Step,
	lo:        Maybe(f32),
	hi:        Maybe(f32),
	format:    Number_Format,
	width:     Sizing,
	disabled:  bool,
	theme:     Input_Theme,
	corners:   Maybe(Corners),
	borders:   Maybe(Edges),
}

// One session, like Text_Edit: only one number scrubs at a time.
Number_Drag :: struct {
	id:          string,
	start_x:     f32,
	accum:       f32,
	moved:       bool,
	enter_sel:   string,
	// The caller's id, never a temp sub-id: a temp string dies with the frame.
	repeat_id:   string,
	repeat_dir:  int,
	repeat_next: u64,
	repeated:    bool,
}

NUMBER_DRAG_SLOP_PX :: f32(3)
NUMBER_SCRUB_DEAD_PX :: f32(1)
// Travel from the press that earns full speed, and the fallback span for the
// frame before clay knows the field's width.
NUMBER_SCRUB_MAX_PX :: f32(100)
NUMBER_SCRUB_RATE_MIN :: f32(1.5)
NUMBER_SCRUB_RATE_MAX :: f32(18)
// Floor for the per-range cap, so a range of a few rungs still scrubs briskly.
NUMBER_SCRUB_RATE_MAX_MIN :: f32(4)
NUMBER_SCRUB_SWEEP_S :: f32(2.5)
NUMBER_FMT_MAX_BYTES :: 32
NUMBER_STEP_MAX :: 64
NUMBER_ARROW_GAP :: u16(4)
// Long enough that a click reads as a click: below ~300ms a normal press already
// lands a second step, so the button feels like it ran away.
NUMBER_REPEAT_DELAY_MS :: u64(400)
NUMBER_REPEAT_RATE_MS :: u64(50)
NUMBER_FRAME_PAD :: u16(3)

Number_Result :: struct {
	value:    f32,
	changed:  bool,
	rejected: bool,
	invalid:  bool,
	clamped:  bool,
	snapped:  bool,
}

// Drag to scrub, arrows to step, click to type. The caller keeps owning `value`;
// `result.value` is what to store, and the flags are edges for the caller to word.
// `step` defaults to 1, `step_proc` overrides it with a ladder (`dir` is +1 or -1
// and needs no clamping), and `lo`/`hi` bound every path.
number_input :: proc(
	ctx: ^Ctx,
	id: string,
	value: f32,
	opts := Number_Opts{},
) -> (
	result: Number_Result,
) {
	result.value = value
	width := opts.width
	if width == nil do width = Sizing_Auto.Grow

	style := input_styles[opts.theme]
	focus := ctx.ui.focused == id
	// The frame lights from anywhere inside it, arrows included.
	frame_id := number_sub_id(id, "frame")
	hover := !opts.disabled && pointer_over(frame_id)
	// Only the number area presses the frame; an arrow click is the arrow's own.
	active := !opts.disabled && (ctx.ui.number.id == id || active_over(ctx.frame, id))
	// A live scrub lights the frame like an edit does.
	scrubbing := !opts.disabled && ctx.ui.number.id == id
	st := color_state(active, hover, scrubbing, focus, opts.disabled)

	// text_input owns clay.ID indices 1..4 of `id`.
	if clay.UI(clay.ID(frame_id))(
	{
		layout = {
			padding = {
				NUMBER_FRAME_PAD,
				NUMBER_FRAME_PAD,
				style.padding.top,
				style.padding.bottom,
			},
			sizing = sizing_to_clay(width),
			childAlignment = {y = .Center},
			childGap = NUMBER_ARROW_GAP,
		},
		border = {
			width = border_width_mask(
				style.border_width,
				nil if focus || scrubbing else opts.borders,
			),
			color = style.border_color[st],
		},
		backgroundColor = style.bg_color[st],
		cornerRadius = corner_radius_mask(style.radius, opts.corners),
	},
	) {
		if number_arrow(ctx, id, -1, .Chev_Left_Small, opts.disabled) {
			result.value = number_stepped(value, -1, opts)
		}

		field := value
		if focus {
			field = number_edit(ctx, id, value, opts, &result)
		} else {
			field = number_display(ctx, id, value, opts)
		}
		if field != value do result.value = field

		if number_arrow(ctx, id, 1, .Chev_Right_Small, opts.disabled) {
			result.value = number_stepped(value, 1, opts)
		}
	}

	result.changed = result.value != value
	return
}

// Steps once per click, then at a fixed rate while the button stays held.
@(private = "file")
number_arrow :: proc(ctx: ^Ctx, id: string, dir: int, glyph: Ui_Icons, disabled: bool) -> bool {
	if disabled do return false

	btn_id := number_sub_id(id, "inc" if dir > 0 else "dec")
	clicked: bool
	if btn, open := button_box(ctx, btn_id, {theme = .Number_Arrow}); open {
		icon(ctx, btn_id, glyph, .Small, btn.fg)
		clicked = btn.clicked
	}
	n := &ctx.ui.number
	// A widening number shifts the arrow out from under a still-held pointer, so a
	// run that has started only needs the button to stay pressed.
	owns := n.repeat_id == id && n.repeat_dir == dir
	held :=
		ctx.frame.gfx.interaction.pressed_id[.Left] == btn_id &&
		platform.mouse_down(ctx.frame.input, .Left) &&
		(pointer_over(btn_id) || owns)
	// A held button emits no events, so the repeat clock needs frames of its own.
	if held do app.frames_owed = max(app.frames_owed, 1)

	fire, ended_run := number_repeat(n, id, dir, held, sdl.GetTicks())
	if ended_run do return false
	return fire || clicked
}

// `ended_run` marks the release that ends a repeat, which is not another step.
@(require_results)
number_repeat :: proc(
	n: ^Number_Drag,
	id: string,
	dir: int,
	held: bool,
	now: u64,
) -> (
	fire: bool,
	ended_run: bool,
) {
	owns := n.repeat_id == id && n.repeat_dir == dir
	if held {
		if !owns {
			n.repeat_id = id
			n.repeat_dir = dir
			n.repeat_next = now + NUMBER_REPEAT_DELAY_MS
			n.repeated = false
			return
		}
		if now < n.repeat_next do return

		n.repeat_next = now + NUMBER_REPEAT_RATE_MS
		n.repeated = true
		return true, false
	}

	if !owns do return
	n.repeat_id = ""
	ended_run = n.repeated
	n.repeated = false
	return
}

@(private = "file")
number_edit :: proc(
	ctx: ^Ctx,
	id: string,
	value: f32,
	opts: Number_Opts,
	result: ^Number_Result,
) -> (
	out: f32,
) {
	out = value

	buf: [NUMBER_FMT_MAX_BYTES]u8
	res := text_input(
		ctx,
		id,
		number_format_default(value, buf[:]),
		{
			theme = .Bare,
			width = .Grow,
			disabled = opts.disabled,
			submits = true,
			transform = number_transform,
			corners = Corners{},
			borders = Edges{},
		},
	)

	// The focusing press landed last frame, so nothing fights for the caret here.
	te := &ctx.ui.text_edit
	if ctx.ui.number.enter_sel == id && te.id == id {
		te.edit.selection = {len(te.builder.buf), 0}
		ctx.ui.number.enter_sel = ""
	}

	result.rejected = res.rejected
	if res.submitted {
		out, result.invalid, result.clamped, result.snapped = number_parse(res.text, value, opts)
	}
	return
}

// Anything parse_f32 refuses keeps `fallback`, and so does an out-of-range
// number: reverting says "that is not allowed" where a silent clamp would read
// as the field accepting a number the caller never typed.
@(require_results)
number_parse :: proc(
	text: string,
	fallback: f32,
	opts: Number_Opts,
) -> (
	out: f32,
	invalid: bool,
	clamped: bool,
	snapped: bool,
) {
	v, ok := strconv.parse_f32(strings.trim_space(text))
	if !ok do return fallback, true, false, false

	if number_clamp(v, opts.lo, opts.hi) != v do return fallback, false, true, false

	out = number_snap(v, opts)
	return out, false, false, out != v
}

// The nearest value the steps can actually produce, so a typed number cannot
// land between two rungs of a ladder or off the grid of a scalar step.
@(require_results)
number_snap :: proc(value: f32, opts: Number_Opts) -> f32 {
	lo, has_lo := opts.lo.?

	if opts.step_proc == nil {
		step := opts.step if opts.step > 0 else 1
		base := lo if has_lo else 0
		return number_clamp(base + math.round((value - base) / step) * step, opts.lo, opts.hi)
	}
	// A ladder is only walkable from a known start.
	if !has_lo do return value

	prev := lo
	for _ in 0 ..< NUMBER_STEP_MAX {
		next := number_clamp(opts.step_proc(prev, 1), opts.lo, opts.hi)
		if next == prev do break
		if next >= value {
			return prev if value - prev <= next - value else next
		}
		prev = next
	}
	return prev
}

@(private = "file")
number_display :: proc(ctx: ^Ctx, id: string, value: f32, opts: Number_Opts) -> (out: f32) {
	out = number_drag(ctx, id, value, opts)

	if register_focusable(ctx, id) do ctx.ui.number.enter_sel = id

	// A held scrub owns the pointer, so fields it crosses stay dark.
	pressed := ctx.frame.gfx.interaction.pressed_id[.Left]
	mine := !opts.disabled && (pressed == "" || pressed == id)
	if (mine && pointer_over(id)) || ctx.ui.number.id == id do ctx.frame.cursor = .Resize_EW

	style := input_styles[opts.theme]
	fg := style.fg_color[.Disabled if opts.disabled else .Normal]

	buf: [NUMBER_FMT_MAX_BYTES]u8
	format := Number_Format(number_format_default)
	if opts.format != nil do format = opts.format
	// clay holds the pointer until render; buf does not live that long.
	label := strings.clone(format(out, buf[:]), context.temp_allocator)

	box_h, glyph_h := text_metrics(style.font, ctx.frame.assets)

	if clay.UI(clay.ID(id))(
	{
		layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(glyph_h)}},
		clip = {horizontal = true},
	},
	) {
		if clay.UI(clay.ID(id, 3))(
		{
			floating = {
				attachTo = .Parent,
				clipTo = .AttachedParent,
				zIndex = 2,
				attachment = {element = .CenterTop, parent = .CenterTop},
				offset = {0, -(box_h - glyph_h)},
				pointerCaptureMode = .Passthrough,
			},
		},
		) {
			text(ctx.frame.assets, label, style.font, fg, .Left, .None)
		}
	}
	return
}

// A press that never travels is a click, which opens the editor.
@(private = "file")
number_drag :: proc(ctx: ^Ctx, id: string, value: f32, opts: Number_Opts) -> (out: f32) {
	out = value
	if opts.disabled do return

	state := &ctx.frame.gfx.interaction
	drag := &ctx.ui.number

	if state.pressed_id[.Left] == "" &&
	   pointer_over(id) &&
	   platform.mouse_pressed(ctx.frame.input, .Left) {
		press_set(state, .Left, id)
		drag^ = {
			id      = id,
			start_x = ctx.frame.input.mouse.pos.x,
		}
	}
	if state.pressed_id[.Left] != id do return

	// interaction_end never runs, so drop our own press.
	if !platform.mouse_down(ctx.frame.input, .Left) {
		state.pressed_id[.Left] = ""
		drag.id = ""
		if !drag.moved {
			ctx.ui.focused = id
			drag.enter_sel = id
		}
		return
	}

	delta_px := ctx.frame.input.mouse.pos.x - drag.start_x
	if abs(delta_px) > NUMBER_DRAG_SLOP_PX do drag.moved = true
	if !drag.moved do return

	// The pointer sets a rate, not a position, so the clock must keep running.
	app.frames_owed = max(app.frames_owed, 1)

	// Travel stops counting after one field width, so a narrow field never
	// reaches the speeds a wide one does.
	el := clay.GetElementData(clay.ID(id))
	span := el.boundingBox.width if el.found else NUMBER_SCRUB_MAX_PX

	rate := number_scrub_rate(delta_px, span, number_scrub_rate_max(opts))
	drag.accum += rate * ctx.frame.dt
	steps := math.trunc(drag.accum)
	drag.accum -= steps
	if steps != 0 do out = number_stepped(value, int(steps), opts)
	return
}

// Steps per second for a pointer `delta_px` from where the press landed: linear
// from a floor rate at the deadzone edge to `rate_max` at NUMBER_SCRUB_MAX_PX,
// and no further than `span_px` of travel. Leaving the deadzone always moves the
// value, slowly; a curve that starts at zero reads as a much wider dead spot.
@(require_results)
number_scrub_rate :: proc(delta_px, span_px, rate_max: f32) -> f32 {
	mag := min(abs(delta_px), span_px)
	if mag <= NUMBER_SCRUB_DEAD_PX do return 0

	t := min((mag - NUMBER_SCRUB_DEAD_PX) / (NUMBER_SCRUB_MAX_PX - NUMBER_SCRUB_DEAD_PX), 1)
	rate_min := min(NUMBER_SCRUB_RATE_MIN, rate_max * 0.25)
	rate := rate_min + t * (rate_max - rate_min)
	return -rate if delta_px < 0 else rate
}

// Full deflection crosses the whole range in about NUMBER_SCRUB_SWEEP_S, so a
// short ladder ticks over slowly while a hundred-step range flies, but never
// below NUMBER_SCRUB_RATE_MAX_MIN or a three-value range feels stuck. It is the
// range, not the steps left ahead, so the scrub does not sag near a bound.
@(require_results)
number_scrub_rate_max :: proc(opts: Number_Opts) -> f32 {
	lo, has_lo := opts.lo.?
	_, has_hi := opts.hi.?
	if !has_lo || !has_hi do return NUMBER_SCRUB_RATE_MAX

	span := max(number_steps_to_end(lo, 1, opts), 1)
	return clamp(span / NUMBER_SCRUB_SWEEP_S, NUMBER_SCRUB_RATE_MAX_MIN, NUMBER_SCRUB_RATE_MAX)
}

// Steps from `from` to the bound in `dir`, or 0 when that end is open. The
// ladder is walked because step_proc need not be uniform.
@(require_results)
number_steps_to_end :: proc(from: f32, dir: int, opts: Number_Opts) -> f32 {
	end, ok := (opts.hi if dir > 0 else opts.lo).?
	if !ok do return 0

	if opts.step_proc == nil {
		step := opts.step if opts.step > 0 else 1
		return abs(end - from) / step
	}

	v := from
	for n in 0 ..< NUMBER_STEP_MAX {
		next := number_clamp(opts.step_proc(v, dir), opts.lo, opts.hi)
		if next == v do return f32(n)
		v = next
	}
	return f32(NUMBER_STEP_MAX)
}

@(require_results)
number_stepped :: proc(value: f32, count: int, opts: Number_Opts) -> f32 {
	if opts.step_proc == nil {
		step := opts.step if opts.step > 0 else 1
		return number_clamp(value + f32(count) * step, opts.lo, opts.hi)
	}

	dir := 1 if count > 0 else -1
	out := value
	for _ in 0 ..< min(abs(count), NUMBER_STEP_MAX) {
		next := number_clamp(opts.step_proc(out, dir), opts.lo, opts.hi)
		if next == out do break
		out = next
	}
	return out
}

@(require_results)
number_clamp :: proc(value: f32, lo, hi: Maybe(f32)) -> f32 {
	out := value
	if l, ok := lo.?; ok && out < l do out = l
	if h, ok := hi.?; ok && out > h do out = h
	return out
}

@(require_results)
number_format_default :: proc(value: f32, buf: []u8) -> string {
	s := strconv.write_float(buf, f64(value), 'f', -1, 32)
	return s[1:] if len(s) > 1 && s[0] == '+' else s
}

@(private = "file")
number_transform :: proc(s: ^Text_Edit, insert: string) -> string {
	b := strings.builder_make(0, len(insert), context.temp_allocator)
	for r in insert {
		switch r {
		case '0' ..= '9', '.', '-':
			strings.write_rune(&b, r)
		}
	}
	return strings.to_string(b)
}

@(private = "file", require_results)
number_sub_id :: proc(id: string, part: string) -> string {
	return strings.concatenate({id, ":", part}, context.temp_allocator)
}
