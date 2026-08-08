package app

// State-level only; geometry, focus and IME placement are manual checks.

import "core:testing"
import "core:unicode/utf8"
import "core:text/edit"

@(test)
test_sanitize_strips_newlines_and_nul :: proc(t: ^testing.T) {
	testing.expect_value(t, input_sanitize("a\r\nb", 64), "ab")
	testing.expect_value(t, input_sanitize("a\nb\rc", 64), "abc")
	testing.expect_value(t, input_sanitize("a\x00b", 64), "ab")
	testing.expect_value(t, input_sanitize("plain", 64), "plain")
}

@(test)
test_sanitize_replaces_invalid_utf8 :: proc(t: ^testing.T) {
	testing.expect_value(t, input_sanitize("a\xffb", 64), "a�b")
}

@(test)
test_sanitize_truncates_on_rune_boundary :: proc(t: ^testing.T) {
	// "é" is 2 bytes: room for 3 fits one and rejects the second whole.
	testing.expect_value(t, input_sanitize("éé", 3), "é")
	testing.expect_value(t, input_sanitize("éé", 4), "éé")
	testing.expect_value(t, input_sanitize("abc", 0), "")
}

@(test)
test_set_sanitizes_and_caps :: proc(t: ^testing.T) {
	s: Text_Input_State
	text_input_init(&s)
	defer text_input_destroy(&s)

	text_input_set(&s, "my\nproject")
	testing.expect_value(t, text_input_get(&s), "myproject")

	long := make([]u8, TEXT_INPUT_MAX_BYTES + 10)
	defer delete(long)
	for &b in long do b = 'x'
	text_input_set(&s, string(long))
	testing.expect_value(t, len(text_input_get(&s)), TEXT_INPUT_MAX_BYTES)
}

// transform gates every insert path; an inverted loop here silently blocks all typing.
@(test)
test_transform_caps_without_blocking :: proc(t: ^testing.T) {
	s: Text_Input_State
	text_input_init(&s)
	defer text_input_destroy(&s)
	s.transform = project_name_transform

	text_input_set(&s, "abc")
	testing.expect_value(t, text_input_get(&s), "abc")

	text_input_set(&s, "0123456789012345678901234567890")
	testing.expect_value(t, text_input_get(&s), "0123456789012345678901234")

	// Full: an insert is refused, but a delete still frees room for one more.
	testing.expect_value(t, input_accept(&s, "z"), "")
	edit.perform_command(&s.edit, .Backspace)
	testing.expect_value(t, input_accept(&s, "zz"), "z")
}

// The refused keystroke is the only place a "that didn't register" hint can come from.
@(test)
test_rejected_flags_only_dropped_inserts :: proc(t: ^testing.T) {
	s: Text_Input_State
	text_input_init(&s)
	defer text_input_destroy(&s)
	s.transform = project_name_transform

	// An insert that lands whole leaves it clear.
	text_input_set(&s, "abc")
	testing.expect_value(t, input_accept(&s, "z"), "z")
	testing.expect(t, !text_input_rejected(&s))

	// Seeding past the cap truncates, but that is not the user losing a keystroke.
	text_input_set(&s, "0123456789012345678901234567890")
	testing.expect_value(t, text_input_get(&s), "0123456789012345678901234")
	testing.expect(t, !text_input_rejected(&s))

	// Full, so the next keystroke is dropped and raises the hint.
	testing.expect_value(t, input_accept(&s, "z"), "")
	testing.expect(t, text_input_rejected(&s))
}

@(test)
test_room_accounts_for_selection :: proc(t: ^testing.T) {
	s: Text_Input_State
	text_input_init(&s)
	defer text_input_destroy(&s)

	text_input_set(&s, "abcd")
	testing.expect_value(t, input_room(&s), TEXT_INPUT_MAX_BYTES - 4)

	// The selection is about to be replaced, so its bytes are available again.
	s.edit.selection = {1, 3}
	testing.expect_value(t, input_room(&s), TEXT_INPUT_MAX_BYTES - 2)
}

// Pins the limitation in text_input_init: codepoint steps, always rune-aligned.
@(test)
test_backspace_steps_by_codepoint :: proc(t: ^testing.T) {
	s: Text_Input_State
	text_input_init(&s)
	defer text_input_destroy(&s)

	text_input_set(&s, "xe\u0301") // base letter + combining acute
	edit.perform_command(&s.edit, .Backspace)
	testing.expect_value(t, text_input_get(&s), "xe")
	testing.expect(t, utf8.valid_string(text_input_get(&s)))

	text_input_set(&s, "x\U0001F469")
	edit.perform_command(&s.edit, .Backspace)
	testing.expect_value(t, text_input_get(&s), "x")
}

@(test)
test_undo_redo_round_trip :: proc(t: ^testing.T) {
	s: Text_Input_State
	text_input_init(&s)
	defer text_input_destroy(&s)

	// No clock running here, so snapshot every edit instead of coalescing.
	s.edit.undo_timeout = -1

	text_input_set(&s, "abc")
	edit.input_text(&s.edit, "def")
	testing.expect_value(t, text_input_get(&s), "abcdef")

	edit.perform_command(&s.edit, .Undo)
	testing.expect_value(t, text_input_get(&s), "abc")
	edit.perform_command(&s.edit, .Redo)
	testing.expect_value(t, text_input_get(&s), "abcdef")
}

// Why input_handle_keys guards .Copy/.Cut.
@(test)
test_copy_without_selection_would_clobber :: proc(t: ^testing.T) {
	s: Text_Input_State
	text_input_init(&s)
	defer text_input_destroy(&s)

	@(static) captured: string
	captured = "unset"
	s.edit.set_clipboard = proc(_: rawptr, text: string) -> bool {
		captured = text
		return true
	}

	text_input_set(&s, "abc") // leaves the caret collapsed at the end
	testing.expect(t, !edit.has_selection(&s.edit))
	edit.perform_command(&s.edit, .Copy)
	testing.expect_value(t, captured, "")
}
