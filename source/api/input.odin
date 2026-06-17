package api

// Per-frame input snapshot. `platform` fills it at the top of each frame;
// editor/UI code reads from it instead of calling raylib directly, keeping
// panels backend-agnostic. This is the IMGUI analogue of an event bus:
// consumers claim the mouse via `capture_mouse` (cf. Dear ImGui's
// io.WantCaptureMouse) instead of subscribing to events.

// Identifies who owns the mouse during a drag. Must be unique app-wide;
// convention: platform uses 1-99, editor panels 100+.
Capture :: distinct u64
CAPTURE_NONE :: Capture(0)

Cursor :: enum {
	Default,
	Resize_EW,
	Pointer,
	Not_Allowed,
}

Input :: struct {
	mouse:         [2]f32, // window-relative, pixels
	left_pressed:  bool,
	left_released: bool,
	left_down:     bool,
	// Who owns the mouse. Persists across frames (lives in App_Memory);
	// claimed on press, released on mouse-up by the owner.
	capture:       Capture,
	// Cursor requested by whoever handled input this frame; platform applies
	// it at end of frame and resets it to .Default on the next poll.
	cursor:        Cursor,
}

// Claim the mouse for `id`. Succeeds if the mouse is free or already ours.
capture_mouse :: proc(input: ^Input, id: Capture) -> bool {
	if input.capture == CAPTURE_NONE || input.capture == id {
		input.capture = id
		return true
	}
	return false
}

has_capture :: proc(input: ^Input, id: Capture) -> bool {
	return input.capture == id
}

release_capture :: proc(input: ^Input, id: Capture) {
	if input.capture == id {
		input.capture = CAPTURE_NONE
	}
}
