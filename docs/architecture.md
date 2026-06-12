# Architecture

How the codebase is organized and the conventions to follow as it grows.
For the "how do I add X" checklists, see [development.md](development.md).

## Packages

```
main_hot_reload ──(dlopen)──► app ──► editor ──► ui ──► (clay, raylib)
main_release ──────────────► app ──► platform
                              app ──► api ◄── (shared types, no deps)
```

- **`api`** — shared types only (`App_Memory`, `Input`), no dependencies. The
  hub everyone imports to avoid circular deps. Keep it dependency-free.
- **`platform`** — OS/window/input isolation. All `when ODIN_OS` / native code
  and all raw raylib *input* calls live here.
- **`ui`** — clay + raylib rendering infrastructure: frame lifecycle
  (`frame_begin`/`frame_end`), text measurement, fonts, colors. Knows _how_ to
  draw, not _what_.
- **`editor`** — application logic: panels and the per-frame update/draw loop.
  Knows _what_ to draw, not _how_. Must not import raylib — it consumes
  `api.Input` and ui/clay only.
- **`app`** — exported entry points (`app_init`, `app_update`, …) wired to both
  the hot-reload host and the release main. Owns per-frame ordering.

Keep the dependency graph one-directional. `ui` must not import `editor`;
`platform` must not import `ui`.

## Input & mouse capture

There is no event bus — this is an immediate-mode app, so input is a
**per-frame snapshot + capture ownership** (the same model as Dear ImGui's
`io.WantCaptureMouse` and clay's pointer state):

1. `platform.poll_input` fills `api.Input` (stored in `App_Memory`) at the top
   of each frame.
2. Handlers run in priority order — `editor.update` first, then
   `platform.handle_window_drag` — each reading the snapshot, never raylib.
3. A drag interaction claims the mouse with `api.capture_mouse(input, ID)` and
   releases it on mouse-up. While captured, everyone else's claims fail, so
   overlapping interactions (sidebar resize vs. titlebar window drag) can't
   both fire.
4. Handlers request a cursor by setting `input.cursor`; `platform.apply_cursor`
   applies it once per frame.

Capture IDs are app-unique `api.Capture` constants: platform uses 1–99,
editor panels 100+.

## Hot reload & persistent state

The hot-reload host (`main_hot_reload`) reloads the app DLL on source change.
Reloading **zeros the DLL's package globals**, so any state that must survive a
reload lives on the heap, reachable from `api.App_Memory` (re-pointed in each
package's `reload` proc).

Practical rule: **persistent state goes in a heap struct stashed in
`App_Memory`, never in package globals.** Globals are fine only for constants
and transient per-frame scratch.

## Frame order

`app_update` is the single place that defines what happens each frame, in order:

```
poll_input → editor.update → handle_window_drag → apply_cursor → editor.draw
```

`editor.draw` opens the clay frame (`ui.frame_begin`), declares each panel
back-to-front, and presents (`ui.frame_end`).

## Build & run

See `mise.toml` tasks: `dev` (hot reload), `run` (standalone debug),
`build` (optimized release).
