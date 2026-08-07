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

// Caller owned, one per text field (ODIN_STYLE.md 2.5: no hidden id-keyed map).
Text_Input_State :: struct {
	edit:     edit.State,
	builder:  strings.Builder,
	scroll_x: f32,
	// SDL_GetTicks at the last edit or caret move; blink derives from it.
	caret_ms: u64,
	// What the held button extends, decided by the click count that started it.
	click_mode: Click_Mode,
	// The word a double-click landed on, as {start, end}. Its far edge stays pinned
	// while the drag extends the near one.
	word_anchor: [2]int,
	// Gates the validator: a field the user has never edited or left shows no error.
	touched:  bool,
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
	validity_color: [Input_Validity]clay.Color,
}

Input_Theme :: enum u8 {
	Default,
}

Click_Mode :: enum u8 {
	Char,
	Word,
	All,
}

Input_Validity :: enum u8 {
	None,
	Warning,
	Error,
}

// Runs per frame, so it must not allocate. `text` aliases the internal buffer; the
// returned message must outlive the frame.
Input_Validator :: #type proc(user_data: rawptr, text: string) -> (Input_Validity, string)

@(rodata)
input_styles := [Input_Theme]Input_Style {
	.Default = {
		font = .UI_REG_13,
		padding = {10, 10, 6, 6},
		bg_color = {
			.Normal = COLOR_GREY_850,
			.Hover = COLOR_GREY_850,
			.Active = COLOR_GREY_850,
			.Engaged = COLOR_GREY_850,
			.Engaged_Hover = COLOR_GREY_850,
			.Engaged_Active = COLOR_GREY_850,
			.Focus = COLOR_GREY_850,
			.Focus_Hover = COLOR_GREY_850,
			.Focus_Active = COLOR_GREY_850,
			.Disabled = COLOR_GREY_805,
		},
		fg_color = {
			.Normal = COLOR_GREY_240,
			.Hover = COLOR_GREY_240,
			.Active = COLOR_GREY_240,
			.Engaged = COLOR_GREY_240,
			.Engaged_Hover = COLOR_GREY_240,
			.Engaged_Active = COLOR_GREY_240,
			.Focus = COLOR_GREY_240,
			.Focus_Hover = COLOR_GREY_240,
			.Focus_Active = COLOR_GREY_240,
			.Disabled = COLOR_GREY_500,
		},
		border_color = {
			.Normal = COLOR_GREY_760,
			.Hover = COLOR_GREY_710,
			.Active = COLOR_GREY_760,
			.Engaged = COLOR_ACCENT,
			.Engaged_Hover = COLOR_ACCENT,
			.Engaged_Active = COLOR_ACCENT,
			.Focus = COLOR_ACCENT,
			.Focus_Hover = COLOR_ACCENT,
			.Focus_Active = COLOR_ACCENT,
			.Disabled = COLOR_GREY_805,
		},
		ph_color = COLOR_GREY_445,
		border_width = {1, 1, 1, 1, 0},
		radius = {5, 5, 5, 5},
		validity_color = {
			.None = COLOR_TRANSPARENT,
			.Warning = COLOR_WARNING,
			.Error = COLOR_ERROR,
		},
	},
}

// allocator backs both the text buffer and the undo/redo history.
text_input_init :: proc(s: ^Text_Input_State, allocator := context.allocator) {
	strings.builder_init(&s.builder, allocator)
	edit.init(&s.edit, allocator, allocator)
	edit.setup_once(&s.edit, &s.builder)
	s.edit.set_clipboard = input_clipboard_set
	s.edit.get_clipboard = input_clipboard_get
	s.edit.clipboard_user_data = s
	// ponytail: no translate_by_grapheme - core subtracts Grapheme.width (a
	// monospace cell count) from a byte offset and corrupts the UTF-8.
}

TEXT_INPUT_MAX_BYTES :: 256

text_input_destroy :: proc(s: ^Text_Input_State) {
	edit.destroy(&s.edit)
	strings.builder_destroy(&s.builder)
}

// Returned string aliases the internal buffer; clone it to keep past this frame.
@(require_results)
text_input_get :: proc(s: ^Text_Input_State) -> string {
	return strings.to_string(s.builder)
}

text_input_set :: proc(s: ^Text_Input_State, value: string) {
	strings.builder_reset(&s.builder)
	strings.write_string(&s.builder, input_sanitize(value, TEXT_INPUT_MAX_BYTES))
	s.edit.selection = {len(s.builder.buf), len(s.builder.buf)}
	s.scroll_x = 0
	s.touched = false
	edit.undo_clear(&s.edit, &s.edit.undo)
	edit.undo_clear(&s.edit, &s.edit.redo)
}

// at_limit is independent of validity: input_sanitize drops the overflow before the
// validator ever sees it.
Text_Input_Result :: struct {
	submitted: bool,
	focused:   bool,
	at_limit:  bool,
	validity:  Input_Validity,
	message:   string,
	color:     clay.Color,
}

/*
Single-line UTF-8 text field, editing via core:text/edit. `state` is caller
owned and must outlive the widget.

`validate` is purely visual, and stays silent until the field is first edited or
blurred so a pristine empty field isn't born in error. An .Error field still accepts
input and still reports `submitted`; enforcing the rule is the caller's job.

width can't be .Fit: the text is a floating child, which contributes nothing to
.Fit sizing, so the box would collapse to padding.
*/
text_input :: proc(
	ctx: ^Ctx,
	id: string,
	state: ^Text_Input_State,
	placeholder: string,
	theme: Input_Theme = .Default,
	validate: Input_Validator = nil,
	validate_user_data: rawptr = nil,
	width: Sizing = .Grow,
	disabled: bool = false,
	submit_on_enter: bool = false,
) -> (
	result: Text_Input_Result,
) {
	if auto, ok := width.(Sizing_Auto); ok {
		assert(
			auto != .Fit,
			"text_input width can't be .Fit (see doc comment); pass .Grow or a fixed size",
		)
	}

	was_focused := ctx.ui.focused == id
	hover := !disabled && pointer_over(id)

	// Tab focus is register_focusable's job, below.
	if !disabled && platform.mouse_pressed(ctx.frame.input, .Left) {
		if hover {
			ctx.ui.focused = id
		} else if was_focused {
			ctx.ui.focused = ""
		}
	}
	if !disabled && register_focusable(ctx, id) {
		ctx.ui.focused = id
		state.edit.selection = {len(state.builder.buf), 0} // tab-in selects all
	}
	focus := ctx.ui.focused == id

	if hover do ctx.frame.cursor = .Text

	style := input_styles[theme]
	active := !disabled && active_over(ctx.frame, id)
	st := color_state(active, hover, false, focus, disabled)
	fg := style.fg_color[st]
	bg := style.bg_color[st]

	selection_was := state.edit.selection
	text_len_was := len(state.builder.buf)

	if focus {
		ctx.ui.wants_text_input = true // ui_frame_end owns the SDL session
		edit.update_time(&state.edit)
		if input_handle_keys(ctx, state, submit_on_enter) {
			result.submitted = true
			ctx.ui.focused = ""
			ctx.ui.wants_text_input = false
		}
	}

	text_str := text_input_get(state)

	if len(state.builder.buf) != text_len_was do state.touched = true
	if was_focused && !focus do state.touched = true
	if result.submitted do state.touched = true

	if validate != nil && state.touched {
		result.validity, result.message = validate(validate_user_data, text_str)
	}

	// Validity outranks hover and focus, so an invalid field can't look healthy just
	// because the pointer is over it. Disabled keeps its grey.
	br := style.border_color[st]
	if result.validity != .None && !disabled do br = style.validity_color[result.validity]

	// Cache owns it and may evict: fetch once a frame, pass it down. nil when
	// empty - SDL_ttf reads a 0 length as NUL-terminated, the builder isn't.
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

	if el.found {
		if focus do input_handle_mouse(ctx, state, id, shaped, el.boundingBox, pad_x)
		input_scroll_clamp(state, shaped, ctx.frame.assets, inner_w)
	}

	if state.edit.selection != selection_was || len(state.builder.buf) != text_len_was {
		state.caret_ms = sdl.GetTicks()
	}

	caret_x := input_caret_x(state, shaped, ctx.frame.assets)

	if el.found && focus {
		input_set_ime_area(ctx, el.boundingBox, caret_x - state.scroll_x)
	}

	if clay.UI(clay.ID(id))(
	{
		layout = {
			padding = style.padding,
			sizing = sizing_to_clay(width),
			childAlignment = {y = .Center},
		},
		border = {width = style.border_width, color = br},
		backgroundColor = bg,
		cornerRadius = style.radius,
	},
	) {
		row_h := input_row_height(style.font, ctx.frame.assets)

		if clay.UI(clay.ID(id, 1))(
		{
			layout = {sizing = {width = clay.SizingGrow(), height = clay.SizingFixed(row_h)}},
			clip = {horizontal = true},
		},
		) {
			if focus && edit.has_selection(&state.edit) {
				input_draw_selection(id, state, shaped, style.font, ctx.frame.assets)
			}

			if clay.UI(clay.ID(id, 3))(
			{
				floating = {
					attachTo = .Parent,
					clipTo = .AttachedParent,
					zIndex = 2,
					attachment = {element = .LeftTop, parent = .LeftTop},
					offset = {-state.scroll_x, 0},
					pointerCaptureMode = .Passthrough,
				},
			},
			) {
				if len(text_str) > 0 {
					text(ctx.frame.assets, text_str, style.font, fg, .Left, .None)
				} else {
					text(ctx.frame.assets, placeholder, style.font, style.ph_color, .Left, .None)
				}
			}

			if focus && blink_on(state.caret_ms) {
				if clay.UI(clay.ID(id, 4))(
				{
					floating = {
						attachTo = .Parent,
						clipTo = .AttachedParent,
						zIndex = 3,
						attachment = {element = .LeftTop, parent = .LeftTop},
						offset = {caret_x - state.scroll_x, 0},
						pointerCaptureMode = .Passthrough,
					},
					layout = {
						sizing = {width = clay.SizingFixed(1.5), height = clay.SizingFixed(row_h)},
					},
					backgroundColor = style.fg_color[.Normal],
				},
				) {}
			}
		}
	}

	// Fresh, not the `focus` local: a submit clears focus mid-proc.
	result.focused = ctx.ui.focused == id
	result.at_limit = len(state.builder.buf) >= TEXT_INPUT_MAX_BYTES
	result.color = style.validity_color[result.validity]
	return result
}

// X of the cluster boundary at offset, logical px from the text origin.
@(private = "file", require_results)
input_offset_x :: proc(shaped: ^ttf.Text, offset: int, asts: ^Assets) -> f32 {
	if shaped == nil || offset <= 0 do return 0

	sub: ttf.SubString
	if !ttf.GetTextSubString(shaped, c.int(offset), &sub) do return 0
	// A caret past the last cluster sits at its trailing edge.
	x := sub.rect.x if c.int(offset) <= sub.offset else sub.rect.x + sub.rect.w
	return f32(x) / asts.scale
}

@(private = "file", require_results)
input_caret_x :: proc(s: ^Text_Input_State, shaped: ^ttf.Text, asts: ^Assets) -> f32 {
	caret := clamp(s.edit.selection[0], 0, len(s.builder.buf))
	return input_offset_x(shaped, caret, asts)
}

// ponytail: one rect, so bidi selections highlight wrong; names are LTR-only.
@(private = "file")
input_draw_selection :: proc(
	id: string,
	s: ^Text_Input_State,
	shaped: ^ttf.Text,
	font: Text,
	asts: ^Assets,
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
			offset = {lo_x - s.scroll_x, 0},
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

// Shared height for every floating child, so they can't drift apart. Full
// ascent+descent, not line_height, or the row's clip scissors descenders.
@(private = "file")
input_row_height :: proc(font: Text, asts: ^Assets) -> f32 {
	return f32(ttf.GetFontHeight(asts.fonts[font])) / asts.scale
}

@(private = "file")
input_scroll_clamp :: proc(s: ^Text_Input_State, shaped: ^ttf.Text, asts: ^Assets, inner_w: f32) {
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
	// PAD is in the bound too, else this cancels the right inset at the end.
	s.scroll_x = clamp(s.scroll_x, 0, max(0, text_w + PAD - inner_w))
}

// No scaling: SDL wants window coords and clay units already are window units.
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
	s: ^Text_Input_State,
	id: string,
	shaped: ^ttf.Text,
	box: clay.BoundingBox,
	pad_x: f32,
) {
	input := ctx.frame.input

	press := platform.mouse_pressed(input, .Left)
	drag := !press && platform.mouse_down(input, .Left)

	if !press && !drag do return
	// Focus can arrive by Tab in the same frame as a click elsewhere; not our press.
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

	// Button still held, possibly without having moved. A triple click already holds
	// everything, so there is nothing left for it to extend into.
	switch s.click_mode {
	case .Char:
		s.edit.selection[0] = hit
	case .Word:
		input_extend_word_selection(s, hit)
	case .All:
	}
}

// Selects the word at `at` and records it as the drag anchor. Both translates read
// selection[0], so seeding it first makes them order-independent.
@(private = "file")
input_select_word_at :: proc(s: ^Text_Input_State, at: int) {
	s.edit.selection = {at, at}
	start := edit.translate_position(&s.edit, .Word_Start)
	end := edit.translate_position(&s.edit, .Word_End)
	s.word_anchor = {start, end}
	s.edit.selection = {end, start}
}

// Grows a double-click's selection to span whole words, from the anchor word out to
// whichever word `at` is in now, so it can never narrow past the anchor.
@(private = "file")
input_extend_word_selection :: proc(s: ^Text_Input_State, at: int) {
	anchor_start, anchor_end := s.word_anchor[0], s.word_anchor[1]

	s.edit.selection = {at, at}
	drag_start := edit.translate_position(&s.edit, .Word_Start)
	drag_end := edit.translate_position(&s.edit, .Word_End)

	// selection[0] is the caret, so the moving edge goes first.
	s.edit.selection =
		[2]int{drag_end, anchor_start} if at >= anchor_start else [2]int{drag_start, anchor_end}
}

// Byte offset of the cluster boundary nearest target_x (logical px).
@(private = "file", require_results)
input_hit_test :: proc(
	s: ^Text_Input_State,
	shaped: ^ttf.Text,
	asts: ^Assets,
	target_x: f32,
) -> int {
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

// Each nav key with its plain, shift, primary, and primary+shift command.
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

// Replays this frame's input events in order (these carry OS auto-repeat,
// unlike the debounced key_pressed flags). True when Enter submits.
@(private = "file")
input_handle_keys :: proc(
	ctx: ^Ctx,
	s: ^Text_Input_State,
	submit_on_enter: bool,
) -> (
	submitted: bool,
) {
	input := ctx.frame.input

	for press in input.text.events[:input.text.events_len] {
		if press.text != "" {
			typed := input_sanitize(press.text, input_room(s))
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
		// Guarded: edit.copy on an empty selection clears the system clipboard.
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

// Cmd on macOS, Ctrl elsewhere.
@(private = "file")
input_mod_primary :: proc(mods: sdl.Keymod) -> bool {
	when ODIN_OS == .Darwin {
		return mods & sdl.KMOD_GUI != {}
	} else {
		return mods & sdl.KMOD_CTRL != {}
	}
}

// Every incoming value crosses here: text_input_set, typed text, and paste.
@(private, require_results)
input_sanitize :: proc(src: string, room: int) -> string {
	if room <= 0 do return ""

	b := strings.builder_make(0, min(len(src), room), context.temp_allocator)
	for r in src { 	// ranging yields RUNE_ERROR for invalid bytes, so U+FFFD is written
		if r == '\r' || r == '\n' || r == 0 do continue
		if strings.builder_len(b) + utf8.rune_size(r) > room do break
		strings.write_rune(&b, r)
	}
	return strings.to_string(b)
}

// Bytes an insert may add: the cap, less what survives the selection it replaces.
@(private, require_results)
input_room :: proc(s: ^Text_Input_State) -> int {
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
	s := (^Text_Input_State)(user_data)
	text = input_sanitize(string(cstring(ptr)), input_room(s))
	return text, len(text) > 0
}
