package app

import "../../vendor/clay"
import "../platform"
import "core:c"
import "core:fmt"
import "core:math"
import "core:strings"
import "core:text/edit"
import "core:unicode/utf8"
import sdl "vendor:sdl3"
import "vendor:sdl3/ttf"

// Caller owned, one per text field (ODIN_STYLE.md 2.5: explicit state over a
// hidden id-keyed global map). Bundles the edit.State machinery (caret,
// selection, undo/redo) with the byte buffer it edits in place.
Text_Input_State :: struct {
	edit:        edit.State,
	builder:     strings.Builder,
	scroll_x:    f32,
	blink_t:     f32,
	// What kind of click is holding the mouse button down right now, so a
	// continued drag knows whether to follow the pointer (see input_handle_mouse).
	click_mode:  Input_Click_Mode,
	// [start, end] of the word a double-click landed on, set at press time.
	// A drag in .Word mode extends outward from whichever side of this word
	// is opposite the drag direction; see input_extend_word_selection.
	word_anchor: [2]int,
}

@(private = "file")
Input_Click_Mode :: enum u8 {
	Char, // plain click: caret follows the pointer every frame of the drag
	Word, // double-click: word selected at press, drag extends whole words
	All, // triple-click: selects everything, drag doesn't touch it
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
	},
}

/*
Initializes a text field's edit state around its own persistent byte buffer.

Inputs:
- allocator: backs both the text buffer and the undo/redo history (default: context.allocator)
*/
text_input_init :: proc(s: ^Text_Input_State, allocator := context.allocator) {
	strings.builder_init(&s.builder, allocator)
	edit.init(&s.edit, allocator, allocator)
	edit.setup_once(&s.edit, &s.builder)
	s.edit.set_clipboard = input_clipboard_set
	s.edit.get_clipboard = input_clipboard_get
}

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
	strings.write_string(&s.builder, value)
	s.edit.selection = {len(s.builder.buf), len(s.builder.buf)}
	edit.undo_clear(&s.edit, &s.edit.undo)
	edit.undo_clear(&s.edit, &s.edit.redo)
}

/*
Single-line UTF-8 text field: caret, selection, undo/redo, clipboard, and
word/line navigation, all via core:text/edit. `state` is caller owned and
must outlive the widget (see Text_Input_State).

width must be .Grow or a fixed pixel size, never .Fit: the displayed text is
a floating child (so it can scroll independently of the box), and floating
elements do not contribute to a parent's .Fit sizing, so a .Fit box collapses
to padding-only with no visible content.

Returns true the frame Enter is pressed with submit_on_enter set; the field
blurs itself on submit.
*/
text_input :: proc(
	ctx: ^Ctx,
	id: string,
	state: ^Text_Input_State,
	placeholder: string,
	theme: Input_Theme = .Default,
	width: Sizing = .Grow,
	disabled: bool = false,
	submit_on_enter: bool = false,
) -> (
	submitted: bool,
) {
	if auto, ok := width.(Sizing_Auto); ok {
		assert(
			auto != .Fit,
			"text_input width can't be .Fit (see doc comment); pass .Grow or a fixed size",
		)
	}

	was_focused := ctx.ui.focused == id
	hover := !disabled && pointer_over(id)

	// Mouse focus: a press inside claims focus, a press elsewhere while
	// focused releases it. Tab focus is handled by register_focusable below.
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
	just_focused := focus && !was_focused

	if hover do ctx.frame.cursor = .Text

	style := input_styles[theme]
	active := !disabled && active_over(ctx.frame, id)
	st := color_state(active, hover, false, focus, disabled)
	fg := style.fg_color[st]
	bg := style.bg_color[st]
	br := style.border_color[st]

	if just_focused {
		if !sdl.StartTextInput(ctx.frame.device.window) {
			fmt.eprintln("failed to start text input")
		}
	} else if was_focused && !focus {
		input_stop_text_input(ctx)
	}

	if focus {
		edit.update_time(&state.edit)
		state.blink_t += ctx.frame.dt
		if input_handle_keys(ctx, state, submit_on_enter) {
			submitted = true
			ctx.ui.focused = ""
			input_stop_text_input(ctx)
		}
	}

	text_str := text_input_get(state)
	el := clay.GetElementData(clay.ID(id))
	pad_x := f32(style.padding.left)
	inner_w := el.boundingBox.width - f32(style.padding.left + style.padding.right)

	if el.found {
		if focus do input_handle_mouse(ctx, state, id, style.font, el.boundingBox, pad_x)
		input_scroll_clamp(state, text_str, style.font, ctx.frame.assets, inner_w)
	}

	caret_byte := clamp(state.edit.selection[0], 0, len(text_str))
	caret_x := text_width(text_str[:caret_byte], style.font, ctx.frame.assets)

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
				input_draw_selection(id, state, text_str, style.font, ctx.frame.assets)
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

			if focus && blink_on(state.blink_t) {
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

	return submitted
}

@(private = "file")
input_draw_selection :: proc(
	id: string,
	s: ^Text_Input_State,
	text_str: string,
	font: Text,
	asts: ^Assets,
) {
	lo, hi := edit.sorted_selection(&s.edit)
	lo_x := text_width(text_str[:lo], font, asts)
	hi_x := text_width(text_str[:hi], font, asts)

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

// Row height, and the shared height every floating child (text, caret,
// selection) sizes itself to. All three sit at offset.y = 0 in this same
// row, so identical height means identical top and bottom edges - they
// can't drift out of alignment with each other by construction. Centering
// within the input box comes from the outer box's own childAlignment.y =
// .Center around this row, not from any per-element offset here.
//
// Full font ascent+descent, not text_styles[font].line_height (the nominal
// single-line advance) - a descender (g, y, p, q, j) needs this much room
// to not get scissored off by the row's clip.
@(private = "file")
input_row_height :: proc(font: Text, asts: ^Assets) -> f32 {
	return f32(ttf.GetFontHeight(asts.fonts[font])) / asts.scale
}

@(private = "file")
input_scroll_clamp :: proc(
	s: ^Text_Input_State,
	text_str: string,
	font: Text,
	asts: ^Assets,
	inner_w: f32,
) {
	PAD :: f32(2)
	caret_x := text_width(text_str[:clamp(s.edit.selection[0], 0, len(text_str))], font, asts)
	if caret_x - s.scroll_x < PAD {
		s.scroll_x = max(0, caret_x - PAD)
	} else if caret_x - s.scroll_x > inner_w - PAD {
		s.scroll_x = caret_x - (inner_w - PAD)
	}
	text_w := text_width(text_str, font, asts)
	s.scroll_x = clamp(s.scroll_x, 0, max(0, text_w - inner_w))
}

@(private = "file")
input_stop_text_input :: proc(ctx: ^Ctx) {
	if !sdl.StopTextInput(ctx.frame.device.window) {
		fmt.eprintln("failed to stop text input")
	}
}

@(private = "file")
input_set_ime_area :: proc(ctx: ^Ctx, box: clay.BoundingBox, caret_local_x: f32) {
	scale := ctx.frame.assets.scale
	rect := sdl.Rect {
		i32(box.x * scale),
		i32(box.y * scale),
		i32(box.width * scale),
		i32(box.height * scale),
	}
	if !sdl.SetTextInputArea(ctx.frame.device.window, &rect, i32(caret_local_x * scale)) {
		fmt.eprintln("failed to set text input area")
	}
}

@(private = "file")
input_handle_mouse :: proc(
	ctx: ^Ctx,
	s: ^Text_Input_State,
	id: string,
	font: Text,
	box: clay.BoundingBox,
	pad_x: f32,
) {
	input := ctx.frame.input
	text_str := text_input_get(s)

	press := platform.mouse_pressed(input, .Left)
	drag := !press && platform.mouse_down(input, .Left)

	if !press && !drag do return
	// Only called while this id already has focus (input_text's mouse-focus
	// block above blurs on any press outside), so a press here is always inside.
	assert(!press || pointer_over(id))

	local_x := input.mouse.pos.x - box.x - pad_x + s.scroll_x
	hit := input_hit_test(text_str, font, ctx.frame.assets, local_x)

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
		s.blink_t = 0
		return
	}

	// The button is still held (drag), possibly with zero mouse movement.
	// A plain click's caret follows the pointer every frame. A double-click
	// extends whole words out from the originally clicked word (never
	// narrower than it). A triple click already selects everything, so a
	// drag has nothing further to extend into.
	switch s.click_mode {
	case .Char:
		if hit != s.edit.selection[0] {
			s.edit.selection[0] = hit
			s.blink_t = 0
		}
	case .Word:
		input_extend_word_selection(s, hit)
	case .All:
	}
}

// Selects the word touching byte offset at (double-click), and records it
// as the drag anchor. Word_Start/End both read from selection[0], so
// setting it to at first gives both calls the same base position
// regardless of call order.
@(private = "file")
input_select_word_at :: proc(s: ^Text_Input_State, at: int) {
	s.edit.selection = {at, at}
	start := edit.translate_position(&s.edit, .Word_Start)
	end := edit.translate_position(&s.edit, .Word_End)
	s.word_anchor = {start, end}
	s.edit.selection = {end, start}
}

// Grows/shrinks a double-click's selection so it always spans whole words,
// from the anchor word (input_select_word_at) out to whichever word at is
// in now. The anchor word's far edge (opposite the drag direction) stays
// pinned; the near edge snaps to the word boundary under the pointer.
@(private = "file")
input_extend_word_selection :: proc(s: ^Text_Input_State, at: int) {
	anchor_start, anchor_end := s.word_anchor[0], s.word_anchor[1]

	s.edit.selection = {at, at}
	drag_start := edit.translate_position(&s.edit, .Word_Start)
	drag_end := edit.translate_position(&s.edit, .Word_End)

	new_selection :=
		[2]int{drag_end, anchor_start} if at >= anchor_start else [2]int{drag_start, anchor_end}
	if new_selection != s.edit.selection {
		s.edit.selection = new_selection
		s.blink_t = 0
	}
}

// Byte offset of the character boundary nearest target_x (logical px, box relative).
@(private = "file", require_results)
input_hit_test :: proc(text_str: string, font: Text, asts: ^Assets, target_x: f32) -> int {
	if len(text_str) == 0 || target_x <= 0 do return 0

	budget_px := c.int(math.floor(target_x * asts.scale))
	measured_w: c.int
	fit_bytes: c.size_t
	ok := ttf.MeasureString(
		asts.fonts[font],
		cstring(raw_data(text_str)),
		c.size_t(len(text_str)),
		budget_px,
		&measured_w,
		&fit_bytes,
	)
	if !ok do return len(text_str)

	lo := int(fit_bytes)
	assert(lo >= 0)
	assert(lo <= len(text_str))
	if lo == len(text_str) do return lo

	_, w := utf8.decode_rune(text_str[lo:])
	hi := lo + w
	lo_x := f32(measured_w) / asts.scale
	hi_x := text_width(text_str[:hi], font, asts)
	return lo if target_x - lo_x < hi_x - target_x else hi
}

@(private = "file")
blink_on :: proc(blink_t: f32) -> bool {
	PERIOD :: f32(1.0)
	return math.mod(blink_t, PERIOD) < PERIOD * 0.5
}

// Keycode-indexed nav table: LEFT/RIGHT/HOME/END/BACKSPACE/DELETE each carry
// their plain, shift-select, ctrl-word, and ctrl+shift-select-word variants.
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

// Processes this frame's typed text and key-down queue (platform.Text_Input
// carries OS auto-repeat, unlike the debounced key_pressed flags buttons use).
// Returns true when Enter was pressed and submit_on_enter is set.
@(private = "file")
input_handle_keys :: proc(
	ctx: ^Ctx,
	s: ^Text_Input_State,
	submit_on_enter: bool,
) -> (
	submitted: bool,
) {
	input := ctx.frame.input

	typed := string(input.text.utf8[:input.text.utf8_len])
	if len(typed) > 0 {
		edit.input_text(&s.edit, typed)
		s.blink_t = 0
	}

	for press in input.text.presses[:input.text.presses_len] {
		if press.key == sdl.K_RETURN || press.key == sdl.K_KP_ENTER {
			if submit_on_enter do submitted = true
			continue
		}

		shift := press.mods & sdl.KMOD_SHIFT != {}
		primary := input_mod_primary(press.mods)
		s.blink_t = 0

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
			edit.perform_command(&s.edit, .Copy)
		case sdl.K_X:
			edit.perform_command(&s.edit, .Cut)
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

// Cmd on macOS, Ctrl elsewhere - the platform-conventional "primary" modifier.
@(private = "file")
input_mod_primary :: proc(mods: sdl.Keymod) -> bool {
	when ODIN_OS == .Darwin {
		return mods & sdl.KMOD_GUI != {}
	} else {
		return mods & sdl.KMOD_CTRL != {}
	}
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

	src := string(cstring(ptr))
	if len(src) == 0 do return "", false
	return strings.clone(src, context.temp_allocator), true
}
