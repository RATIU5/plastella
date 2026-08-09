package app

// State only; geometry, focus and IME placement are manual checks.

import "core:strings"
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
	s: Text_Edit
	defer text_edit_destroy(&s)

	text_edit_begin(&s, "t", "my\nproject", nil)
	testing.expect_value(t, strings.to_string(s.builder), "myproject")

	long := make([]u8, TEXT_INPUT_MAX_BYTES + 10)
	defer delete(long)
	for &b in long do b = 'x'
	text_edit_begin(&s, "t", string(long), nil)
	testing.expect_value(t, len(strings.to_string(s.builder)), TEXT_INPUT_MAX_BYTES)
}

// transform gates every insert path; getting it wrong blocks all typing.
@(test)
test_transform_caps_without_blocking :: proc(t: ^testing.T) {
	s: Text_Edit
	defer text_edit_destroy(&s)

	text_edit_begin(&s, "t", "abc", project_name_transform)
	testing.expect_value(t, strings.to_string(s.builder), "abc")

	text_edit_begin(&s, "t", "0123456789012345678901234567890", project_name_transform)
	testing.expect_value(t, strings.to_string(s.builder), "0123456789012345678901234")

	// Full: the insert is refused, but a delete frees room for one more.
	testing.expect_value(t, input_accept(&s, "z"), "")
	edit.perform_command(&s.edit, .Backspace)
	testing.expect_value(t, input_accept(&s, "zz"), "z")
}

@(test)
test_rejected_flags_only_dropped_inserts :: proc(t: ^testing.T) {
	s: Text_Edit
	defer text_edit_destroy(&s)

	text_edit_begin(&s, "t", "abc", project_name_transform)
	testing.expect_value(t, input_accept(&s, "z"), "z")
	testing.expect(t, !s.rejected)

	// A truncated seed is not a lost keystroke.
	text_edit_begin(&s, "t", "0123456789012345678901234567890", project_name_transform)
	testing.expect_value(t, strings.to_string(s.builder), "0123456789012345678901234")
	testing.expect(t, !s.rejected)

	testing.expect_value(t, input_accept(&s, "z"), "")
	testing.expect(t, s.rejected)
}

@(test)
test_room_accounts_for_selection :: proc(t: ^testing.T) {
	s: Text_Edit
	defer text_edit_destroy(&s)

	text_edit_begin(&s, "t", "abcd", nil)
	testing.expect_value(t, input_room(&s), TEXT_INPUT_MAX_BYTES - 4)

	// The selection is about to be replaced, so its bytes count as free.
	s.edit.selection = {1, 3}
	testing.expect_value(t, input_room(&s), TEXT_INPUT_MAX_BYTES - 2)
}

// Backspace steps by codepoint, never mid-rune.
@(test)
test_backspace_steps_by_codepoint :: proc(t: ^testing.T) {
	s: Text_Edit
	defer text_edit_destroy(&s)

	text_edit_begin(&s, "t", "xe\u0301", nil) // base letter + combining acute
	edit.perform_command(&s.edit, .Backspace)
	testing.expect_value(t, strings.to_string(s.builder), "xe")
	testing.expect(t, utf8.valid_string(strings.to_string(s.builder)))

	text_edit_begin(&s, "t", "x\U0001F469", nil)
	edit.perform_command(&s.edit, .Backspace)
	testing.expect_value(t, strings.to_string(s.builder), "x")
}

@(test)
test_undo_redo_round_trip :: proc(t: ^testing.T) {
	s: Text_Edit
	defer text_edit_destroy(&s)

	text_edit_begin(&s, "t", "abc", nil)

	// No clock here, so snapshot every edit instead of coalescing.
	s.edit.undo_timeout = -1

	edit.input_text(&s.edit, "def")
	testing.expect_value(t, strings.to_string(s.builder), "abcdef")

	edit.perform_command(&s.edit, .Undo)
	testing.expect_value(t, strings.to_string(s.builder), "abc")
	edit.perform_command(&s.edit, .Redo)
	testing.expect_value(t, strings.to_string(s.builder), "abcdef")
}

// Why input_handle_keys guards .Copy/.Cut.
@(test)
test_copy_without_selection_would_clobber :: proc(t: ^testing.T) {
	s: Text_Edit
	defer text_edit_destroy(&s)

	@(static) captured: string
	captured = "unset"

	text_edit_begin(&s, "t", "abc", nil) // leaves the caret collapsed at the end
	s.edit.set_clipboard = proc(_: rawptr, text: string) -> bool {
		captured = text
		return true
	}

	testing.expect(t, !edit.has_selection(&s.edit))
	edit.perform_command(&s.edit, .Copy)
	testing.expect_value(t, captured, "")
}
