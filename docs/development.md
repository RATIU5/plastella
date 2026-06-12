# Development guide

Checklists and conventions for adding code. Background: [architecture.md](architecture.md).

## Adding a panel

One file per panel in `source/editor/` (e.g. `sidebar.odin`):

1. Define `<Panel>_State` in the panel's file and add one field to
   `Editor_State` (`sidebar: Sidebar_State`). Never use package globals for
   panel state — it must live under `Editor_State` to survive hot reloads.
2. Expose `<panel>_update :: proc(input: ^api.Input)` and
   `<panel>_draw :: proc()`.
3. Register them: `_update` in `editor.update`, `_draw` in `editor.draw`
   (between `ui.frame_begin`/`frame_end`, back-to-front order).
4. Set initial field values in `editor.init`.

## Handling input

- Read input only from `api.Input` — never call raylib input functions in
  `editor`.
- For drags (resize, pan, paint), define a unique capture ID
  (`MY_PANEL_CAPTURE :: api.Capture(101)` — panels use 100+) and:
  claim with `api.capture_mouse` on press, act only while
  `api.has_capture`, release on `input.left_released`.
- Request cursors by setting `input.cursor`; don't call `rl.SetMouseCursor`.
- Need a new input field (right button, scroll, a key)? Add it to `api.Input`
  and fill it in `platform.poll_input`. Keep the snapshot flat plain data.

## Adding a subsystem (rare)

A new package with persistent state (like `ui` or `editor`) needs the full
lifecycle wiring or it will silently break hot reload / leak:

1. Heap-allocate its state struct in an `init` that returns the pointer.
2. Store that pointer in `api.App_Memory`.
3. Add a `reload(rawptr)` that re-points the package's state pointer (and
   re-sets any C-library globals), called from `app_hot_reloaded`.
4. Add a `shutdown` that frees everything, called from `app_shutdown`.

## Styling

- Colors are named constants in `ui/colors.odin` (`COLOR_*`, `[4]f32` RGBA
  0–255). Don't inline color literals in panels.
- Fonts are entries in `ui.FONT`, loaded in `ui.init_clay`. Name them
  `ROLE_WEIGHT_SIZE` (e.g. `BODY_REG_14`).
- Clay element IDs (`clay.ID("Sidebar")`) name the *container's role*, not its
  content, and must be unique per frame.

## Naming

- Types: `Ada_Case` (`Sidebar_State`). Procs/fields: `snake_case`. Constants:
  `SCREAMING_SNAKE`.
- Panel procs are prefixed with the panel name (`sidebar_update`); package
  names already scope everything else, so don't repeat them (`ui.init_clay`,
  not `ui.ui_init_clay`).

## Build & run

- `mise run dev` — hot reload (edit, save, see it live; F5 force reload,
  F6 force restart).
- `mise run run` — standalone debug build.
- `mise run build` — optimized release.

Builds use `-strict-style -vet`; code must pass both.
