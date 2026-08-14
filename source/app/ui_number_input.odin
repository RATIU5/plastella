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
	repeat_id:   string,
	repeat_next: u64,
	repeated:    bool,
}

NUMBER_DRAG_SLOP_PX :: f32(3)
NUMBER_SCRUB_DEAD_PX :: f32(1)
NUMBER_SCRUB_MAX_PX :: f32(100)
NUMBER_SCRUB_RATE_MIN :: f32(1.5)
NUMBER_SCRUB_RATE_MAX :: f32(30)
NUMBER_SCRUB_SWEEP_S :: f32(0.8)
NUMBER_SCRUB_BOOST :: f32(4)
// 0 is a straight line, 1 is fully quadratic.
NUMBER_SCRUB_EASE :: f32(0.35)
NUMBER_FMT_MAX_BYTES :: 32
NUMBER_STEP_MAX :: 64
NUMBER_ARROW_GAP :: u16(4)
NUMBER_REPEAT_DELAY_MS :: u64(75)
NUMBER_REPEAT_RATE_MS :: u64(50)
NUMBER_FRAME_PAD :: u16(3)

Number_Result :: struct {
	value:    f32,
	changed:  bool,
	rejected: bool,
	invalid:  bool,
	clamped:  bool,
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
	st := color_state(active, hover, false, focus, opts.disabled)

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
			width = border_width_mask(style.border_width, nil if focus else opts.borders),
			color = style.border_color[st],
		},
		backgroundColor = style.bg_color[st],
		cornerRadius = corner_radius_mask(style.radius, opts.corners),
	},
	) {
		// ponytail: placeholders until the atlas has chevrons.
		if number_arrow(ctx, number_sub_id(id, "dec"), "<", opts.disabled) {
			result.value = number_stepped(value, -1, opts)
		}

		field := value
		if focus {
			field = number_edit(ctx, id, value, opts, &result)
		} else {
			field = number_display(ctx, id, value, opts)
		}
		if field != value do result.value = field

		if number_arrow(ctx, number_sub_id(id, "inc"), ">", opts.disabled) {
			result.value = number_stepped(value, 1, opts)
		}
	}

	result.changed = result.value != value
	return
}

// Steps once per click, then at a fixed rate while the button stays held.
@(private = "file")
number_arrow :: proc(ctx: ^Ctx, id: string, label: string, disabled: bool) -> bool {
	if disabled do return false

	clicked := button(ctx, id, label, {theme = .Number_Arrow})
	held :=
		ctx.frame.gfx.interaction.pressed_id[.Left] == id &&
		platform.mouse_down(ctx.frame.input, .Left) &&
		pointer_over(id)
	// A held button emits no events, so the repeat clock needs frames of its own.
	if held do app.frames_owed = max(app.frames_owed, 1)

	fire, ended_run := number_repeat(&ctx.ui.number, id, held, sdl.GetTicks())
	if ended_run do return false
	return fire || clicked
}

// `ended_run` marks the release that ends a repeat, which is not another step.
@(require_results)
number_repeat :: proc(
	n: ^Number_Drag,
	id: string,
	held: bool,
	now: u64,
) -> (
	fire: bool,
	ended_run: bool,
) {
	if held {
		if n.repeat_id != id {
			n.repeat_id = id
			n.repeat_next = now + NUMBER_REPEAT_DELAY_MS
			n.repeated = false
			return
		}
		if now < n.repeat_next do return

		n.repeat_next = now + NUMBER_REPEAT_RATE_MS
		n.repeated = true
		return true, false
	}

	if n.repeat_id != id do return
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
		out, result.invalid, result.clamped = number_parse(res.text, value, opts)
	}
	return
}

// Anything parse_f32 refuses keeps `fallback`, so a bad commit reverts.
@(require_results)
number_parse :: proc(
	text: string,
	fallback: f32,
	opts: Number_Opts,
) -> (
	out: f32,
	invalid: bool,
	clamped: bool,
) {
	v, ok := strconv.parse_f32(strings.trim_space(text))
	if !ok do return fallback, true, false

	out = number_clamp(v, opts.lo, opts.hi)
	return out, false, out != v
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
				attachment = {element = .LeftTop, parent = .LeftTop},
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
		state.pressed_id[.Left] = id
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

	drag.accum += number_scrub_rate(delta_px, number_scrub_rate_max(opts)) * ctx.frame.dt
	steps := math.trunc(drag.accum)
	drag.accum -= steps
	if steps != 0 do out = number_stepped(value, int(steps), opts)
	return
}

// Steps per second for a pointer `delta_px` from where the press landed: an
// ease-in curve from a floor rate, with the outer half ramping into
// NUMBER_SCRUB_BOOST on top of it. Leaving the deadzone always moves the value,
// slowly; a curve that starts at zero reads as a much wider dead spot.
@(require_results)
number_scrub_rate :: proc(delta_px, rate_max: f32) -> f32 {
	mag := min(abs(delta_px), NUMBER_SCRUB_MAX_PX)
	if mag <= NUMBER_SCRUB_DEAD_PX do return 0

	t := (mag - NUMBER_SCRUB_DEAD_PX) / (NUMBER_SCRUB_MAX_PX - NUMBER_SCRUB_DEAD_PX)
	curve := t * (1 - NUMBER_SCRUB_EASE) + t * t * NUMBER_SCRUB_EASE
	if t > 0.5 do curve *= 1 + NUMBER_SCRUB_BOOST * (t - 0.5) * 2

	rate_min := min(NUMBER_SCRUB_RATE_MIN, rate_max * 0.25)
	rate := rate_min + curve * (rate_max - rate_min)
	return -rate if delta_px < 0 else rate
}

// The curve's pre-boost ceiling. A bounded range is paced so that full
// deflection, boost included, sweeps it in about NUMBER_SCRUB_SWEEP_S, which is
// what makes the middle of a three-value ladder landable.
@(require_results)
number_scrub_rate_max :: proc(opts: Number_Opts) -> f32 {
	span := number_range_steps(opts)
	if span <= 0 do return NUMBER_SCRUB_RATE_MAX
	return min(span / NUMBER_SCRUB_SWEEP_S / (1 + NUMBER_SCRUB_BOOST), NUMBER_SCRUB_RATE_MAX)
}

// Steps between lo and hi, or 0 when either end is open. The ladder is walked
// because step_proc need not be uniform.
@(require_results)
number_range_steps :: proc(opts: Number_Opts) -> f32 {
	lo, has_lo := opts.lo.?
	hi, has_hi := opts.hi.?
	if !has_lo || !has_hi do return 0

	if opts.step_proc == nil {
		step := opts.step if opts.step > 0 else 1
		return (hi - lo) / step
	}

	v := lo
	for n in 0 ..< NUMBER_STEP_MAX {
		next := number_clamp(opts.step_proc(v, 1), opts.lo, opts.hi)
		if next <= v do return f32(n)
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
