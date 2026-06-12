# Architecture

How the codebase is organized and the conventions to follow as it grows.

## Packages

```
main_hot_reload ──(dlopen)──► app ──► editor ──► ui ──► (clay, raylib)
main_release ──────────────► app ──► platform
                              app ──► api ◄── (shared types, no deps)
```

- **`api`** — shared types only (`App_Memory`), no dependencies. The hub everyone
  imports to avoid circular deps. Keep it dependency-free.
- **`platform`** — OS/window isolation. All `when ODIN_OS` / native code lives here.
- **`ui`** — clay + raylib rendering infrastructure: frame lifecycle
  (`frame_begin`/`frame_end`), text measurement, fonts, color conversion. Knows
  _how_ to draw, not _what_.
- **`editor`** — application logic: panels and the per-frame update/draw loop.
  Knows _what_ to draw, not _how_.
- **`app`** — exported entry points (`app_init`, `app_update`, …) wired to both
  the hot-reload host and the release main.

Keep the dependency graph one-directional. `ui` must not import `editor`;
`platform` must not import `ui`.

## Hot reload & persistent state

The hot-reload host (`main_hot_reload`) reloads the app DLL on source change.
Reloading **zeros the DLL's package globals**, so any state that must survive a
reload lives on the heap, reachable from `api.App_Memory` (re-pointed in each
package's `reload` proc).

Practical rule: **persistent state goes in a heap struct stashed in
`App_Memory`, never in package globals.** Globals are fine only for constants and
transient per-frame scratch.

## Panel convention

For every new panel in `editor`:

1. **One file per panel** (e.g. `sidebar.odin`), exposing `<panel>_update` and
   `<panel>_draw` procs.
2. **Panel state lives in `Editor_State`** — never in package globals.
   `Editor_State` is heap-allocated and stashed in `App_Memory`, so its fields
   survive hot reloads. Group fields per panel as they grow
   (e.g. `sidebar: Sidebar_State`).
3. **Register the panel** by calling its `_update` in `editor.update` and its
   `_draw` in `editor.draw` (between `ui.frame_begin`/`frame_end`, in
   back-to-front draw order).

## Build & run

See `mise.toml` tasks: `dev` (hot reload), `run` (standalone debug),
`build` (optimized release).
