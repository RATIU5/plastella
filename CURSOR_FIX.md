# Cursor state fix

Goal: the mouse cursor should reset itself each frame instead of sticking
(e.g. staying a pointer after you leave a button), with no flicker and no
per-call-site teardown.

## Model

Immediate mode: every frame re-runs the whole UI, so whatever handler is
hovered *this* frame re-asserts its cursor. So:

- Each frame starts at `.DEFAULT`.
- Handlers (`button`, sidebar resize) call `set_cursor(...)` during layout; last writer wins.
- The result is pushed to raylib **once** per frame, and only when the shape actually changed → no flicker.

`set_cursor` becomes a pure state write. `update_input` owns the push+reset.
It already runs once per lap between raylib's event pump and UI building, so
no change to `render.odin` is needed.

## Steps — all in `source/platform/input_raylib.odin`

### 1. Add a field to track what raylib currently shows

Near the existing `cursor: Mouse_Cursor,` field (~line 21):

```odin
cursor_applied: Mouse_Cursor,
```

### 2. Make `set_cursor` a pure store (drop the rl call)

`set_cursor` (~line 218):

```odin
set_cursor :: proc(cursor: Mouse_Cursor) {
	state.cursor = cursor
}
```

### 3. Push + reset at the top of `update_input`

`update_input` (~line 278), as the first thing in the proc:

```odin
update_input :: proc() {
	// push the cursor requested last lap, then default for this one
	if state.cursor != state.cursor_applied {
		rl.SetMouseCursor(rl_mouse_cursor[state.cursor])
		state.cursor_applied = state.cursor
	}
	state.cursor = .DEFAULT

	// ... existing body unchanged ...
}
```

## Step — in `source/editor/sidebar.odin`

The old reset workaround is now dead (the frame reset handles it). Replace the
`if / else if` cursor block (~lines 54-56) with just:

```odin
if near || sidebar_mem.resizing do platform.set_cursor(.RESIZE_EW)
```

## Nothing else changes

Call sites (`ui.button`, sidebar) keep calling `set_cursor` exactly as they
do. `get_cursor` may now be unused — check and delete if so.

## Notes

- One-lap latency: a cursor set while building frame N is pushed at the start
  of frame N+1. Imperceptible.
- `cursor_applied` is what prevents redundant same-value pushes (the source of
  the flicker). Keep it.
- The earlier flicker came from pushing two different shapes per frame
  (DEFAULT then hand). Pushing once, on-change-only, removes that.
