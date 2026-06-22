# UI Refactor — Path to a Compiling Window

Branch: `ui-refactor`. Goal: cut the clashing old/new code down to a clean,
raylib-only path that compiles and shows a window, then rebuild widgets and the
editor on top of the new `io`/`render`/`ui` stack.

## The architecture we're rebuilding toward

Clay is immediate-mode: the widget tree only exists as the `clay.UI(...)` calls
made *between* `render.frame_begin()` and `render.frame_end()`. So widgets don't
"live in" render or app — they're declared in the gap. Four layers, each owns one
thing:

| Package  | Owns                                                                 |
|----------|----------------------------------------------------------------------|
| `render` | the mechanism: clay+raylib pump and draw, query helpers (`pointer_over`, `clicked`) |
| `ui`     | reusable widget *procs* (`button`) — stateless, called during the gap |
| `editor` | *composition*: declares the actual tree (sidebar, panels) via `ui.*` + `clay.UI` |
| `app`    | *ordering*: `frame_begin → editor.frame → frame_end`, plus window lifecycle |

The frame, end to end:

```odin
render.frame_begin()   // io.update_input(); clay.BeginLayout(...mouse)
editor.frame()         // declares the widget tree  ← the gap
render.frame_end()     // clay.EndLayout() → render commands → draw
```

**`app` owns the begin/end pair**, not editor. (Today `editor.frame` calls them
internally — that moves to `app`.) Milestone 1 is just this gap left empty.

## No global capture

The old `api.Capture` id-arbiter is gone. Widgets already don't use it — buttons
resolve hover/click through clay hit-testing (`render.pointer_over`) plus live
raylib state (`io.mouse_down`). The only thing that ever needed capture is a
**drag** (sidebar resize, window drag), and a drag survives the cursor leaving the
widget on its own, because `io.mouse_down(.LEFT)` is global raylib state. So each
drag uses a local bool:

```odin
// in Sidebar_State: resizing: bool
if near && io.mouse_press(.LEFT) do sb.resizing = true
if io.mouse_release(.LEFT)      do sb.resizing = false
if sb.resizing do sb.width = clamp(io.mouse_pos().x, SIDEBAR_MIN, SIDEBAR_MAX)
// ponytail: per-widget drag flag; add a global arbiter only if two drag
// regions can ever claim the same press (they can't today)
```

---

## Step 0 — What to remove so it compiles (blank window)

Odin only builds packages reachable from `main`. Drop the imports and the
`api`/`platform`/`editor` packages fall out of the build entirely — **leave those
files on disk to rewrite later.** Concrete edits, all in `app/app.odin`:

1. **Drop imports** `api`, `platform`, `editor`. Keep `render`, `ui`, and add
   `io`. (`api`, `platform`, `editor` now compile to nothing — ignore them.)
2. **Move `App_Memory` into `app`** (it's the only thing app used from `api`):
   ```odin
   App_Memory :: struct { run: bool, render_state: rawptr, editor: rawptr }
   ```
   `editor` field can stay a `rawptr` (harmless) or be dropped — your call when
   you rewrite the editor.
3. **Replace the `app_update` body** with just the empty gap:
   ```odin
   if io.window_minimized() { io.idle_pump_events(); return }
   render.frame_begin()
   render.frame_end()
   free_all(context.temp_allocator)
   ```
   Drops the now-dead `platform.poll_input` / `editor.frame` / `handle_window_drag`
   / `apply_cursor` and the `am.input` reference (which never existed on
   `App_Memory` — a current break).
4. **Point window lifecycle at `io`**: `app_init_window`, `app_shutdown_window`,
   `app_should_run`, the minimized check → `io.*`. This requires Step-1 below
   (moving the lifecycle procs into `io`); until then they don't resolve.
5. **`app_init` / `app_shutdown`**: drop `editor.init()` / `editor.shutdown()`
   and the `editor` field init. Keep `render.render_init()` / `render_shutdown()`.
6. **`app_memory_layout_hash`**: drop the `editor.Editor_State` line; hash only
   the local `App_Memory`.
7. **`app_set_reload_status`**: `ui.dev_notice_show/hide` don't exist yet —
   another current break. Stub the body to `// TODO: reload toast` for now.

After Step 0 + Step 1, you have a window. Any remaining errors are contained to
`app` + `io`.

---

## Milestones to rebuild

### M1 — Window lifecycle into `io`
Move `init_window` / `shutdown_window` / `window_should_close` /
`window_minimized` / `idle_pump_events` / `setup_fullsize_titlebar` (and the F5/F6
force-reload helpers) from `platform/window.odin` into a new `io/window.odin`.
**Leave `handle_window_drag` and `global_cursor` behind** — they come back in M3.
With Step 0 done, this is what makes the blank window actually compile and run.

### M2 — Window drag back (local bool, no capture)
Bring `handle_window_drag` + `global_cursor` + the titlebar hit-test into
`io/window.odin`, rewritten to a local `@(static) dragging: bool` instead of
`capture_mouse`. Drive it from `io.mouse_press/release(.LEFT)`, `io.mouse_pos()`,
`io.screen_pos()`, `io.screen_scale()`. Call `io.handle_window_drag()` from
`app_update` **after** `editor.frame` (so UI gets first claim on the click).

### M3 — Editor back on `io`
1. `editor.frame :: proc()` — drop the `^api.Input` param. Reads go through `io`.
   Remove its internal `render.frame_begin/end` (app owns those now).
2. `editor/sidebar.odin`: drop `import api`; replace the capture dance with the
   local `resizing` bool (see "No global capture" above); cursor via
   `io.set_cursor(.RESIZE_EW)`. Reconcile against the current `ui.button` API.
3. `editor/editor.odin`: drop `import api`, drop the `input` param threading.
4. Re-enable in `app_update`: `frame_begin(); editor.frame(); frame_end()`.

### M4 — Reload toast (optional, when you want it)
Add `ui.dev_notice_show/hide` and wire `app_set_reload_status` back up. Pure
feature; skip until the rest is solid.

### M5 — Delete the old world
Delete `source/api/` and `source/platform/`. Confirm nothing references them:
`grep -rn '"../api"\|"../platform"' source/`.

---

## Decisions (so you don't stall mid-milestone)

- **`io` owns the whole OS surface** (window + input + lifecycle). Rename
  `io` → `platform` only as a *separate* pass after the window is back — never mix
  a rename into a compile-fix.
- **Keep the `be.BACKEND == .Raylib` gate for now.** It compiles and isn't in the
  way. Commit to raylib (drop the `when` gating + `render_backend` package) as its
  own cleanup later, via `-collection:` directory-per-backend if you ever need
  swappable backends — not `when` blocks.
- **`update_input` runs once per frame inside `render.frame_begin`.** It drains
  raylib's char queue, so it must stay exactly once per frame. Window drag runs
  after `editor.frame` reading live raylib queries, so order is fine.
