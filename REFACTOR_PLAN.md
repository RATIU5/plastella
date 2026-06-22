# UI Refactor — Path to a Compiling Window

Branch: `ui-refactor`. Goal: unwind the clashing old/new code into a clean,
raylib-only architecture that compiles and shows a window, then layer features
back.

## The core clash

Two parallel input worlds are wired into the same call graph:

| Concern  | Old (still live)                          | New (still live)        |
|----------|-------------------------------------------|-------------------------|
| Input    | `api.Input` struct + `platform/input.odin`| `io` query procs        |
| Capture  | `api.capture_*(^Input)`                    | **missing in `io`**     |
| Window   | `platform/window.odin` (needs `api.Input`)| —                       |
| Consumers| `app`, `editor`, `editor/sidebar`         | `render`, `ui/button`   |

The `render`/`io`/`ui` side compiles internally (self-consistent, gated). The
break is that **`app` and `editor` still speak `api.Input`**, `editor/sidebar`
imports the *new* `ui` (whose `button.odin` was rewritten against `io`/`render`),
and window-drag needs `api.Input` which capture hasn't moved off yet. The old and
new halves meet in `app_update` and `editor.frame` and don't agree.

The one true blocker behind all of it: **capture hasn't migrated to `io`**, so
`api` can't be deleted, so the old path can't die.

## Strategy

Don't migrate everything and compile once at the end. Cut the call graph down to
`main → app → window → render(clear)`, prove the window, then re-add capture, then
the editor.

---

## Milestone 1 — Blank window (cut editor + capture out of the path)

Goal: a window that clears to a color, compiling.

1. **`app.odin`**: remove `import api` and the `input: api.Input` field from
   `App_Memory` (leave `api/types.odin` for now, just stop using the field). In
   `app_update`, replace the body with:
   `if io.window_minimized { io.idle_pump_events(); return }` then a bare
   `render.frame_begin(); render.frame_end()`. Drop the `platform.poll_input` /
   `handle_window_drag` / `apply_cursor` calls and `editor.frame` **temporarily**.
2. **Window lifecycle into `io`**: move `init_window` / `shutdown_window` /
   `window_should_close` / `window_minimized` / `idle_pump_events` from
   `platform/window.odin` into a new `io/window.odin`. **Leave `handle_window_drag`
   and the macOS titlebar behind for now** (they need capture). Point `app`'s
   `init_window` / `shutdown_window` / `should_run` exports at `io.*`.
3. **`editor.frame`**: stub it to nothing, or just don't call it yet.
4. Delete nothing yet. Build. **You should get a window.** If it won't compile,
   the errors are now contained to `app` + `io` only.

## Milestone 2 — Capture lands in `io`

Move capture so the old `api` can die.

5. **New `io/capture.odin`**: port `Capture`, `CAPTURE_NONE`, and
   `capture_mouse(id)` / `has_capture(id)` / `release_capture(id)` — but as
   **package-global** over `io`'s `state` (no `^Input` param). Add a
   `capture: Capture` field to `Input_State`.
6. **Focus handling in `update_input`**: the old `poll_input` had the one
   sanctioned focus-loss reset (park mouse, clear capture, cancel in-flight drag).
   The new `update_input` doesn't check focus — add an early
   `if !rl.IsWindowFocused()` branch that clears `state.capture`. This is the
   *only* place capture resets; do **not** clear it in the normal per-frame reset
   (it spans frames).
7. Note you no longer need `api.Input`'s `backspace_all/word`, `delete_forward`,
   `escape`, `chars` fields — editor queries those directly via
   `io.key_press(.ESCAPE)`, `io.mod_down(.SUPER)`, `io.chars_typed()`. The query
   model replaces the snapshot struct.

## Milestone 3 — Window drag back, on io capture

8. Bring `handle_window_drag` + macOS titlebar into `io/window.odin`, rewritten to
   use `io.capture_mouse(WINDOW_DRAG_CAPTURE)`, `io.mouse_press(.LEFT)`,
   `io.mouse_release(.LEFT)`, `io.screen_scale()`, `io.screen_pos()`.
   `global_cursor` (the NS/raylib leaf) stays here too. Call
   `io.handle_window_drag()` from `app_update` after `editor.frame`.

## Milestone 4 — Editor back on io

9. **`editor.frame`**: drop the `input: ^api.Input` param entirely →
   `frame :: proc()`. Reads happen via `io`.
10. **`editor/sidebar.odin`**: replace `api.Capture(100)` → `io.Capture(100)`,
    `api.capture_mouse(input, ...)` → `io.capture_mouse(...)`, etc. Remove
    `import api`. Reconcile against the new `ui.button` API (this is where the
    `ui` rewrite meets `sidebar` — likely some signature fixes).
11. **`editor.odin`**: remove `import api`, drop the `input` param from the
    `frame` / `sidebar` calls.
12. Re-enable `editor.frame()` in `app_update`.

## Milestone 5 — Delete the old world

13. Delete `source/api/` and `source/platform/` entirely. Confirm no references
    remain (`grep -rn '"../api"\|"../platform"'`). Drop the now-unused `input`
    field/import traces.

---

## Decisions (so you don't stall mid-milestone)

- **Capture as package-global is right** for the new model — `editor` and
  window-drag both reach it without threading a struct, matching how `io.state`
  already works.
- **Keep the `be`/`render_backend` gate for now.** It compiles and isn't in your
  way. Drop it + rename `io`→`platform` as a *separate* cleanup pass **after** the
  window is back — don't mix a rename into a compile-fix.
- **One subtlety to watch**: `io.update_input` currently runs *inside*
  `render.frame_begin`, so input is pumped mid-frame. `handle_window_drag` runs
  after `editor.frame` and reads live raylib queries, so it's fine — but if you
  ever move `update_input` out of `render`, keep it exactly once per frame (it
  drains the char queue).

## Future cleanup (after the window is back, not now)

- Commit to raylib: drop the `when be.BACKEND == .Raylib` gating and the
  `render_backend` package. Reintroduce swappable backends only if you outgrow
  raylib (custom shaders / web target) — and via `-collection:backend=...`
  (directory-per-backend packages), **not** `when` blocks.
- Rename `io` → `platform` so the one OS-surface package (window + input +
  capture + lifecycle) names its concern accurately.
