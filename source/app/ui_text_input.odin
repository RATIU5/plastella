package app

import "../../vendor/clay"
import "../platform"
import "core:c"
import "core:fmt"
import "core:strings"
import "core:text/edit"
import "core:unicode/utf8"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"

// One session for the whole app. commit_* outlives it: the field that owned the
// session may draw after the one that stole focus.
Text_Edit :: struct {
	id:          string,
	commit_id:   string,
	commit_buf:  [TEXT_INPUT_MAX_BYTES]u8,
	commit_len:  int,
	edit:        edit.State,
	builder:     strings.Builder,
	scroll_x:    f32,
	caret_ms:    u64,
	click_mode:  Click_Mode,
	word_anchor: [2]int,
	transform:   Input_Transform,
	rejected:    bool,
}

Input_Opts :: struct {
	placeholder: string,
	theme:       Input_Theme,
	width:       Sizing,
	disabled:    bool,
	// Enter and blur commit; Escape backs out.
	submits:     bool,
	transform:   Input_Transform,
	// nil rounds every corner and draws every edge; set them to sit flush with a
	// neighbour. A focused field always draws all four edges.
	corners:     Maybe(Corners),
	borders:     Maybe(Edges),
}

Input_Style :: struct {
	font:         Text,
	padding:      clay.Padding,
	border_width: clay.BorderWidth,
	border_color: [Color_State]clay.Color,
	bg_color:     [Color_State]clay.Color,
	fg_color:     [Color_State]clay.Color,
	ph_color:     clay.Color,
	radius:       clay.CornerRadius,
}

Input_Theme :: enum u8 {
	Default,
}

Click_Mode :: enum u8 {
	Char,
	Word,
	All,
}

// Rewrites text on its way into the buffer; return "" to reject the whole insert.
// Runs on typing, paste, and the seed at focus. `insert` is only the incoming text:
// read s.builder and s.edit.selection for what is already there. The result is
// sanitized and clamped to the byte cap afterwards.
Input_Transform :: #type proc(s: ^Text_Edit, insert: string) -> string

TEXT_INPUT_MAX_BYTES :: 256

@(rodata)
input_styles := [Input_Theme]Input_Style {
	.Default = {
		font = .UI_REG_13,
		padding = {5, 5, 5, 5},
		bg_color = {
			.Normal = COLOR_GREY_740,
			.Hover = COLOR_GREY_710,
			.Active = COLOR_GREY_935,
			.Engaged = COLOR_GREY_935,
			.Engaged_Hover = COLOR_GREY_935,
			.Engaged_Active = COLOR_GREY_935,
			.Focus = COLOR_GREY_935,
			.Focus_Hover = COLOR_GREY_935,
			.Focus_Active = COLOR_GREY_935,
			.Disabled = COLOR_GREY_805,
		},
		fg_color = {
			.Normal = COLOR_GREY_150,
			.Hover = COLOR_GREY_150,
			.Active = COLOR_GREY_150,
			.Engaged = COLOR_GREY_150,
			.Engaged_Hover = COLOR_GREY_150,
			.Engaged_Active = COLOR_GREY_150,
			.Focus = COLOR_GREY_150,
			.Focus_Hover = COLOR_GREY_150,
			.Focus_Active = COLOR_GREY_150,
			.Disabled = COLOR_GREY_500,
		},
		border_color = {
			.Normal = COLOR_TRANSPARENT,
			.Hover = COLOR_TRANSPARENT,
			.Active = COLOR_TRANSPARENT,
			.Engaged = COLOR_ACCENT,
			.Engaged_Hover = COLOR_ACCENT,
			.Engaged_Active = COLOR_ACCENT,
			.Focus = COLOR_ACCENT,
			.Focus_Hover = COLOR_ACCENT,
			.Focus_Active = COLOR_ACCENT,
			.Disabled = COLOR_ACCENT,
		},
		ph_color = COLOR_GREY_395,
		border_width = {1, 1, 1, 1, 0},
		radius = {5, 5, 5, 5},
	},
}

@(private)
text_edit_begin :: proc(s: ^Text_Edit, id: string, value: string, transform: Input_Transform) {
	if s.builder.buf.allocator.procedure == nil {
		strings.builder_init(&s.builder)
		edit.init(&s.edit, context.allocator, context.allocator)
		edit.setup_once(&s.edit, &s.builder)
		s.edit.set_clipboard = input_clipboard_set
		s.edit.get_clipboard = input_clipboard_get
		s.edit.clipboard_user_data = s
	}
	s.id = id
	s.transform = transform
	s.scroll_x = 0
	strings.builder_reset(&s.builder)
	s.edit.selection = {0, 0} // stale offsets misreport the room to input_accept
	strings.write_string(&s.builder, input_accept(s, value))
	s.edit.selection = {len(s.builder.buf), len(s.builder.buf)}
	s.rejected = false // a truncated seed is not a lost keystroke
	edit.undo_clear(&s.edit, &s.edit.undo)
	edit.undo_clear(&s.edit, &s.edit.redo)
}

@(private = "file")
text_edit_end :: proc(s: ^Text_Edit, commit: bool) {
	if commit {
		s.commit_id = s.id
		s.commit_len = copy(s.commit_buf[:], strings.to_string(s.builder))
	}
	s.id = ""
}

@(private)
text_edit_destroy :: proc(s: ^Text_Edit) {
	edit.destroy(&s.edit)
	strings.builder_destroy(&s.builder)
}

Text_Input_Result :: struct {
	submitted: bool,
	text:      string,
	focused:   bool,
	at_limit:  bool,
	// Edge: true only on the frame an insert was dropped.
	rejected:  bool,
}

// Single-line UTF-8 field. The caller keeps owning `value`, shown while not
// editing; edited text comes back through `result.text` on commit.
text_input :: proc(
	ctx: ^Ctx,
	id: string,
	value: string,
	opts := Input_Opts{},
) -> (
	result: Text_Input_Result,
) {
	if auto, ok := opts.width.(Sizing_Auto); ok {
		assert(
			auto != .Fit,
			"text_input width can't be .Fit (see doc comment); pass .Grow or a fixed size",
		)
	}
	width := opts.width
	if width == nil do width = Sizing_Auto.Grow

	te := &ctx.ui.text_edit
	was_focused := ctx.ui.focused == id
	hover := !opts.disabled && pointer_over(id)

	if !opts.disabled && platform.mouse_pressed(ctx.frame.input, .Left) {
		if hover {
			ctx.ui.focused = id
		} else if was_focused {
			ctx.ui.focused = ""
		}
	}
	tabbed := !opts.disabled && register_focusable(ctx, id)
	if tabbed do ctx.ui.focused = id
	focus := ctx.ui.focused == id

	// Blur commits; Escape and window focus loss (see ui_update) revert instead.
	if te.id == id && !focus {
		backed_out := platform.key_pressed(ctx.frame.input, .ESCAPE) || ctx.frame.input.focus_lost
		text_edit_end(te, !backed_out)
	}
	if focus && te.id != id {
		if te.id != "" do text_edit_end(te, true)
		text_edit_begin(te, id, value, opts.transform)
		if tabbed do te.edit.selection = {len(te.builder.buf), 0}
	}

	if hover do ctx.frame.cursor = .Text

	style := input_styles[opts.theme]
	active := !opts.disabled && active_over(ctx.frame, id)
	st := color_state(active, hover, false, focus, opts.disabled)

	selection_was := te.edit.selection
	text_len_was := len(te.builder.buf)

	if focus {
		ctx.ui.wants_text_input = true
		edit.update_time(&te.edit)
		if input_handle_keys(ctx, te, opts.submits) {
			text_edit_end(te, true)
			ctx.ui.focused = ""
			ctx.ui.wants_text_input = false
		}
	}

	if te.commit_id == id {
		result.submitted = opts.submits
		result.text = string(te.commit_buf[:te.commit_len])
		te.commit_id = ""
	}

	editing := te.id == id
	text_str := value
	// Cloned: clay holds this pointer until render, and a later field stealing focus
	// this frame resets the shared builder underneath it.
	if editing do text_str = strings.clone(strings.to_string(te.builder), context.temp_allocator)
	else if result.submitted do text_str = result.text

	// Cache may evict, so fetch once a frame and pass it down. Left nil when empty:
	// SDL_ttf reads a 0 length as NUL-terminated, the builder is not.
	shaped: ^ttf.Text
	if len(text_str) > 0 {
		shaped = text_cache_get(
			&ctx.frame.gfx.text_cache,
			ctx.frame.device,
			ctx.frame.assets,
			text_str,
			style.font,
		)
	}

	el := clay.GetElementData(clay.ID(id))
	pad_x := f32(style.padding.left)
	inner_w := el.boundingBox.width - f32(style.padding.left + style.padding.right)

	caret_x := f32(0)
	if editing {
		if el.found {
			input_handle_mouse(ctx, te, id, shaped, el.boundingBox, pad_x)
			input_scroll_clamp(te, shaped, ctx.frame.assets, inner_w)
		}
		if te.edit.selection != selection_was || len(te.builder.buf) != text_len_was {
			te.caret_ms = sdl.GetTicks()
		}
		caret_x = input_caret_x(te, shaped, ctx.frame.assets)
		if el.found do input_set_ime_area(ctx, el.boundingBox, caret_x - te.scroll_x)

		result.at_limit = len(te.builder.buf) >= TEXT_INPUT_MAX_BYTES
		result.rejected = te.rejected
		te.rejected = false
	}

	input_draw(
		ctx,
		te,
		{
			id = id,
			style = style,
			text = text_str,
			placeholder = opts.placeholder,
			width = width,
			shaped = shaped,
			fg = style.fg_color[st],
			bg = style.bg_color[st],
			border = style.border_color[st],
			caret_x = caret_x,
			scroll_x = te.scroll_x if editing else 0,
			focus = editing,
			radius = corner_radius_mask(style.radius, opts.corners),
			border_width = border_width_mask(style.border_width, nil if focus else opts.borders),
		},
	)

	result.focused = ctx.ui.focused == id
	return result
}

@(private = "file")
Input_Draw :: struct {
	id:           string,
	style:        Input_Style,
	text:         string,
	placeholder:  string,
	width:        Sizing,
	shaped:       ^ttf.Text,
	fg:           clay.Color,
	bg:           clay.Color,
	border:       clay.Color,
	caret_x:      f32,
	scroll_x:     f32,
	focus:        bool,
	radius:       clay.CornerRadius,
	border_width: clay.BorderWidth,
}

@(private = "file")
input_draw :: proc(ctx: ^Ctx, s: ^Text_Edit, d: Input_Draw) {
	if clay.UI(clay.ID(d.id))(
	{
		layout = {
			padding = d.style.padding,
			sizing = sizing_to_clay(d.width),
			childAlignment = {y = .Center},
		},
		border = {width = d.border_width, color = d.border},
		backgroundColor = d.bg,
		cornerRadius = d.radius,
	},
	) {
		row_h := input_row_height(d.style.font, ctx.frame.assets)

		if clay.UI(clay.ID(d.id, 1))(
		{
			layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(row_h)}},
			clip = {horizontal = true},
		},
		) {
			if d.focus && edit.has_selection(&s.edit) {
				input_draw_selection(d.id, s, d.shaped, d.style.font, ctx.frame.assets, d.scroll_x)
			}

			if clay.UI(clay.ID(d.id, 3))(
			{
				floating = {
					attachTo = .Parent,
					clipTo = .AttachedParent,
					zIndex = 2,
					attachment = {element = .LeftTop, parent = .LeftTop},
					offset = {-d.scroll_x, -input_leading(d.style.font, ctx.frame.assets)},
					pointerCaptureMode = .Passthrough,
				},
			},
			) {
				if len(d.text) > 0 {
					text(ctx.frame.assets, d.text, d.style.font, d.fg, .Left, .None)
				} else {
					text(
						ctx.frame.assets,
						d.placeholder,
						d.style.font,
						d.style.ph_color,
						.Left,
						.None,
					)
				}
			}

			if d.focus && blink_on(s.caret_ms) {
				if clay.UI(clay.ID(d.id, 4))(
				{
					floating = {
						attachTo = .Parent,
						clipTo = .AttachedParent,
						zIndex = 3,
						attachment = {element = .LeftTop, parent = .LeftTop},
						offset = {d.caret_x - d.scroll_x, 0},
						pointerCaptureMode = .Passthrough,
					},
					layout = {
						sizing = {width = clay.SizingFixed(1.5), height = clay.SizingFixed(row_h)},
					},
					backgroundColor = d.style.fg_color[.Normal],
				},
				) {}
			}
		}
	}
}

// X of the cluster boundary at `offset`, logical px from the text origin.
@(private = "file", require_results)
input_offset_x :: proc(shaped: ^ttf.Text, offset: int, asts: ^Assets) -> f32 {
	if shaped == nil || offset <= 0 do return 0

	sub: ttf.SubString
	if !ttf.GetTextSubString(shaped, c.int(offset), &sub) do return 0
	x := sub.rect.x if c.int(offset) <= sub.offset else sub.rect.x + sub.rect.w
	return f32(x) / asts.scale
}

@(private = "file", require_results)
input_caret_x :: proc(s: ^Text_Edit, shaped: ^ttf.Text, asts: ^Assets) -> f32 {
	caret := clamp(s.edit.selection[0], 0, len(s.builder.buf))
	return input_offset_x(shaped, caret, asts)
}

@(private = "file")
input_draw_selection :: proc(
	id: string,
	s: ^Text_Edit,
	shaped: ^ttf.Text,
	font: Text,
	asts: ^Assets,
	scroll_x: f32,
) {
	lo, hi := edit.sorted_selection(&s.edit)
	lo_x := input_offset_x(shaped, lo, asts)
	hi_x := input_offset_x(shaped, hi, asts)
	if clay.UI(clay.ID(id, 2))(
	{
		floating = {
			attachTo = .Parent,
			clipTo = .AttachedParent,
			zIndex = 1,
			attachment = {element = .LeftTop, parent = .LeftTop},
			offset = {lo_x - scroll_x, 0},
			pointerCaptureMode = .Passthrough,
		},
		layout = {
			sizing = {
				width = clay.SizingFixed(hi_x - lo_x),
				height = clay.SizingFixed(input_row_height(font, asts)),
			},
		},
		backgroundColor = opacity(COLOR_ACCENT, 100),
	},
	) {}
}

// Shared by every floating child so they can't drift. Glyphs only: the style's
// leading would push a single-line field off center.
@(private = "file")
input_row_height :: proc(font: Text, asts: ^Assets) -> f32 {
	_, glyph_h := text_metrics(font, asts)
	return glyph_h
}

// The text child draws glyphs on the bottom edge of a taller box; this lifts them.
@(private = "file")
input_leading :: proc(font: Text, asts: ^Assets) -> f32 {
	box_h, glyph_h := text_metrics(font, asts)
	return box_h - glyph_h
}

@(private = "file")
input_scroll_clamp :: proc(s: ^Text_Edit, shaped: ^ttf.Text, asts: ^Assets, inner_w: f32) {
	PAD :: f32(2)
	caret_x := input_caret_x(s, shaped, asts)
	if caret_x - s.scroll_x < PAD {
		s.scroll_x = max(0, caret_x - PAD)
	} else if caret_x - s.scroll_x > inner_w - PAD {
		s.scroll_x = caret_x - (inner_w - PAD)
	}

	text_w := f32(0)
	if shaped != nil {
		w, h: c.int
		if ttf.GetTextSize(shaped, &w, &h) do text_w = f32(w) / asts.scale
	}
	// PAD is in the bound too, else the right inset is cancelled at the end.
	s.scroll_x = clamp(s.scroll_x, 0, max(0, text_w + PAD - inner_w))
}

// No scaling: clay units are already window units.
@(private = "file")
input_set_ime_area :: proc(ctx: ^Ctx, box: clay.BoundingBox, caret_local_x: f32) {
	rect := sdl.Rect{i32(box.x), i32(box.y), i32(box.width), i32(box.height)}
	if !sdl.SetTextInputArea(ctx.frame.device.window, &rect, i32(caret_local_x)) {
		fmt.eprintln("failed to set text input area")
	}
}

@(private = "file")
input_handle_mouse :: proc(
	ctx: ^Ctx,
	s: ^Text_Edit,
	id: string,
	shaped: ^ttf.Text,
	box: clay.BoundingBox,
	pad_x: f32,
) {
	input := ctx.frame.input

	press := platform.mouse_pressed(input, .Left)
	drag := !press && platform.mouse_down(input, .Left)

	if !press && !drag do return
	if press && !pointer_over(id) do return

	local_x := input.mouse.pos.x - box.x - pad_x + s.scroll_x
	hit := input_hit_test(s, shaped, ctx.frame.assets, local_x)

	if press {
		switch {
		case input.mouse.clicks >= 3:
			s.click_mode = .All
			edit.perform_command(&s.edit, .Select_All)
		case input.mouse.clicks == 2:
			s.click_mode = .Word
			input_select_word_at(s, hit)
		case:
			s.click_mode = .Char
			s.edit.selection = {hit, hit}
		}
		return
	}

	switch s.click_mode {
	case .Char:
		s.edit.selection[0] = hit
	case .Word:
		input_extend_word_selection(s, hit)
	case .All:
	}
}

// Selects the word at `at` as the drag anchor. Both translates read selection[0],
// so it is seeded first.
@(private = "file")
input_select_word_at :: proc(s: ^Text_Edit, at: int) {
	s.edit.selection = {at, at}
	start := edit.translate_position(&s.edit, .Word_Start)
	end := edit.translate_position(&s.edit, .Word_End)
	s.word_anchor = {start, end}
	s.edit.selection = {end, start}
}

// Extends a double-click selection by whole words, never inside the anchor.
@(private = "file")
input_extend_word_selection :: proc(s: ^Text_Edit, at: int) {
	anchor_start, anchor_end := s.word_anchor[0], s.word_anchor[1]

	s.edit.selection = {at, at}
	drag_start := edit.translate_position(&s.edit, .Word_Start)
	drag_end := edit.translate_position(&s.edit, .Word_End)

	s.edit.selection =
		[2]int{drag_end, anchor_start} if at >= anchor_start else [2]int{drag_start, anchor_end}
}

// Byte offset of the cluster boundary nearest target_x, in logical px.
@(private = "file", require_results)
input_hit_test :: proc(s: ^Text_Edit, shaped: ^ttf.Text, asts: ^Assets, target_x: f32) -> int {
	if shaped == nil || target_x <= 0 do return 0

	sub: ttf.SubString
	if !ttf.GetTextSubStringForPoint(shaped, c.int(target_x * asts.scale), 0, &sub) {
		return len(s.builder.buf)
	}
	if sub.rect.w <= 0 do return int(sub.offset)

	mid := f32(sub.rect.x) + f32(sub.rect.w) * 0.5
	return int(sub.offset) if target_x * asts.scale < mid else int(sub.offset + sub.length)
}

@(private = "file", require_results)
blink_on :: proc(caret_ms: u64) -> bool {
	PERIOD :: u64(1000)
	return (sdl.GetTicks() - caret_ms) % PERIOD < PERIOD / 2
}

@(private = "file")
Nav_Key :: struct {
	key:        sdl.Keycode,
	plain:      edit.Command,
	shift:      edit.Command,
	ctrl:       edit.Command,
	ctrl_shift: edit.Command,
}

@(private = "file", rodata)
nav_keys := [?]Nav_Key {
	{sdl.K_LEFT, .Left, .Select_Left, .Word_Left, .Select_Word_Left},
	{sdl.K_RIGHT, .Right, .Select_Right, .Word_Right, .Select_Word_Right},
	{sdl.K_HOME, .Start, .Select_Start, .Start, .Select_Start},
	{sdl.K_END, .End, .Select_End, .End, .Select_End},
	{sdl.K_BACKSPACE, .Backspace, .Backspace, .Delete_Word_Left, .Delete_Word_Left},
	{sdl.K_DELETE, .Delete, .Delete, .Delete_Word_Right, .Delete_Word_Right},
}

// Replays this frame's events in order; unlike key_pressed they carry OS auto-repeat.
@(private = "file")
input_handle_keys :: proc(ctx: ^Ctx, s: ^Text_Edit, submit_on_enter: bool) -> (submitted: bool) {
	input := ctx.frame.input

	for press in input.text.events[:input.text.events_len] {
		if press.text != "" {
			typed := input_accept(s, press.text)
			if len(typed) > 0 do edit.input_text(&s.edit, typed)
			continue
		}

		if press.key == sdl.K_RETURN || press.key == sdl.K_KP_ENTER {
			if submit_on_enter do submitted = true
			continue
		}

		shift := press.mods & sdl.KMOD_SHIFT != {}
		primary := input_mod_primary(press.mods)

		nav_handled := false
		for nk in nav_keys {
			if press.key != nk.key do continue
			cmd := nk.plain
			switch {
			case primary && shift:
				cmd = nk.ctrl_shift
			case primary:
				cmd = nk.ctrl
			case shift:
				cmd = nk.shift
			}
			edit.perform_command(&s.edit, cmd)
			nav_handled = true
			break
		}
		if nav_handled do continue
		if !primary do continue

		switch press.key {
		case sdl.K_A:
			edit.perform_command(&s.edit, .Select_All)
		case sdl.K_C:
			if edit.has_selection(&s.edit) do edit.perform_command(&s.edit, .Copy)
		case sdl.K_X:
			if edit.has_selection(&s.edit) do edit.perform_command(&s.edit, .Cut)
		case sdl.K_V:
			edit.perform_command(&s.edit, .Paste)
		case sdl.K_Z:
			edit.perform_command(&s.edit, .Redo if shift else .Undo)
		case sdl.K_Y:
			edit.perform_command(&s.edit, .Redo)
		}
	}
	return
}

@(private = "file")
input_mod_primary :: proc(mods: sdl.Keymod) -> bool {
	when ODIN_OS == .Darwin {
		return mods & sdl.KMOD_GUI != {}
	} else {
		return mods & sdl.KMOD_CTRL != {}
	}
}

@(private, require_results)
input_sanitize :: proc(src: string, room: int) -> string {
	if room <= 0 do return ""

	b := strings.builder_make(0, min(len(src), room), context.temp_allocator)
	for r in src { 	// ranging yields RUNE_ERROR for invalid bytes, written back as U+FFFD
		if r == '\r' || r == '\n' || r == 0 do continue
		if strings.builder_len(b) + utf8.rune_size(r) > room do break
		strings.write_rune(&b, r)
	}
	return strings.to_string(b)
}

// Every insert passes here: caller's transform, then sanitize and clamp.
@(private, require_results)
input_accept :: proc(s: ^Text_Edit, src: string) -> string {
	kept := src
	if s.transform != nil do kept = s.transform(s, kept)
	out := input_sanitize(kept, input_room(s))
	if len(out) < len(src) do s.rejected = true
	return out
}

// Bytes an insert may add, counting the selection it replaces as free.
@(private, require_results)
input_room :: proc(s: ^Text_Edit) -> int {
	lo, hi := edit.sorted_selection(&s.edit)
	return TEXT_INPUT_MAX_BYTES - len(s.builder.buf) + (hi - lo)
}

@(private = "file")
input_clipboard_set :: proc(user_data: rawptr, text: string) -> bool {
	cstr := strings.clone_to_cstring(text, context.temp_allocator)
	return sdl.SetClipboardText(cstr)
}

@(private = "file")
input_clipboard_get :: proc(user_data: rawptr) -> (text: string, ok: bool) {
	ptr := sdl.GetClipboardText()
	if ptr == nil do return "", false
	defer sdl.free(rawptr(ptr))

	// ok=false makes an empty or fully-rejected paste a no-op in edit.paste.
	s := (^Text_Edit)(user_data)
	text = input_accept(s, string(cstring(ptr)))
	return text, len(text) > 0
}
