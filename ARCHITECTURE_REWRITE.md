# Architecture Rewrite

A plan to rebuild plastella's foundation around one owned state graph, stable
widget identity, a disciplined allocator model, and an SDL3 rendering backend.
This document is the target, not an audit. It records what we are moving away
from only where it explains what we are moving toward.

Measured against `ODIN_STYLE.md`, ordered by leverage: fix the roots first, and
the many small issues collapse into easy follow-ups.

---

## 0. Goals

1. **Safety.** One owner per piece of state, no dangling pointers across a
   frame, no silent corruption across a hot reload.
2. **Performance.** No per-frame secret allocations, no linear scans for widget
   identity, no re-hashing the same key several times per widget.
3. **Developer experience.** Adding a subsystem or a widget is one obvious edit,
   not five coordinated ones spread across packages.

The rendering-backend pivot (raylib → SDL3) and the memory re-architecture land
in the **same pass**, because they touch the same files. Doing them separately
means rewriting `platform` and `render` twice.

---

## 1. Rendering backend: raylib → SDL3 (with Clay retained)

### Decision

Move window, input, and 2D rendering from raylib to **SDL3 + SDL_Renderer**.
Keep **Clay** for layout. Own text rendering.

### Why it is affordable

Clay is renderer-agnostic: it emits a list of render commands (rects, text,
images, borders, scissor rects) and does not care who draws them. The UI code —
`ui/button.odin`, `ui/input.odin`, `editor/sidebar.odin`, all layout — does not
change. The blast radius is the backend behind seams we already built:

- `platform/*_raylib.odin` → `platform/*_sdl.odin` (window, input, clipboard, cursor)
- `render/clay_raylib.odin` → the SDL command consumer
- `render/render.odin`, `render/text.odin`, `render/fonts.odin`, `render/textures.odin`

The existing `platform/input_api.odin` seam proves the design: the backend is
quarantined behind a narrow interface (STYLE §6). This is an implementation swap
behind seams, not a rewrite of the app.

### Why SDL3 is the right call for an editor

- **Text input / IME.** SDL3's `SDL_StartTextInput` + `SDL_EVENT_TEXT_INPUT`
  event model replaces draining raylib's `GetCharPressed` queue into a fixed
  rune buffer. Composition and non-Latin input become correct, and
  `ui/input.odin` gets simpler.
- **Windowing.** Better HiDPI, native drag regions (we hand-roll
  `window_begin_drag` today), a cleaner event pump, multi-window later.
- **Library, not framework.** SDL hands us `SDL_Window*` / `SDL_Renderer*` that
  *we* own and store in our own state. Raylib keeps hidden global state, which
  fights the caller-owned direction of this rewrite.

### The one real cost: we now own text

SDL_Renderer draws textures and geometry but does not render fonts. Two paths:

1. **SDL_ttf 3.x** — text engine integrates with SDL_Renderer and caches
   glyphs. Least work, one more dependency.
2. **stb_truetype + our own atlas** — more control, more code, no extra dep.

Either way, Clay's text-measure callback (`measure_text`) is reimplemented on
the new font system. This is the long pole of the port; everything else is
mechanical.

**De-risk first (STYLE §6):** confirm Odin bindings exist for `vendor:sdl3` and
the chosen font path, then prove one glyph on screen with a working
`measure_text`, before committing the rest.

### Scope: one renderer, for now

Use SDL_Renderer for **all** UI chrome. Do not split "UI renderer vs other
renderer" yet. The only place that may later want custom shaders is the **map
canvas** (this is a tilemap editor: Maps / Tilesets / Sprites / Level_Editor). If
that single viewport needs it, drop *that panel* to SDL3_gpu or GL behind the
same render seam. Design the seam to allow it; do not build it now.

---

## 2. Major Issue 1 — One owned state graph

### The problem we are removing

Each subsystem is reachable three ways: a field in `App_Memory`, a duplicate
package global (`render.state`, `ui.ui_mem`, `editor.editor_mem`,
`editor.sidebar_mem`), and — for project — a third copy in `editor_mem.project`.
Reload safety depends on a hand-maintained chain of `*_reload` repoints spread
across packages. STYLE §3.9 and Appendix A both target this exact shape.

This is already broken in practice: `App_Memory.project_mem` is **never
assigned**. `app_init` never creates the project; the real project pointer is
created inside `sidebar.project_frame` and stored only in `editor_mem.project`.
The declared top-level owner has lost track of the object. That is the
"out of sync" failure STYLE §3.9 warns about, already live.

### Target: one persistent arena, one root, one repoint

**2.1 The host owns a persistent arena**, distinct from per-frame temp.

```
// host/main.odin
main :: proc() {
    // gpa = tracking allocator, as today

    persistent_arena: Arena
    arena_init(&persistent_arena, backing = gpa)
    persistent := arena_allocator(&persistent_arena)   // named by role (STYLE §3.5)

    api.init(persistent)          // pass the arena in; no hidden context.allocator
    // ... main loop ...
    // temp still freed each lap: free_all(context.temp_allocator)
}
```

**2.2 One root struct.** Sub-states are owned fields, and SDL handles live here
so they survive a hot reload. Each state has exactly one owner field.

```
// app/app.odin
App_Memory :: struct {
    persistent: Allocator,        // the arena, so reload/shutdown use the same one

    platform: Platform_Memory,    // SDL_Window*, SDL_Renderer*, input snapshot
    render:   Render_Memory,      // font atlas / text engine, clay context + buffer
    ui:       UI_Memory,
    editor:   Editor_Memory,
    project:  Project_Memory,     // the ONE canonical project home
}
mem: ^App_Memory                  // the single root global (a cache of a pointer)
```

**2.3 Subsystem init takes the target and allocator, initializes in place**
(STYLE §3.9), and does not set a hidden global inside itself.

```
platform_init :: proc(p: ^Platform_Memory, persistent: Allocator)          // creates SDL window + renderer
render_init   :: proc(r: ^Render_Memory,   persistent: Allocator)          // font atlas, clay ctx
ui_init       :: proc(u: ^UI_Memory,       persistent: Allocator)
editor_init   :: proc(e: ^Editor_Memory, project: ^Project_Memory, persistent: Allocator) // borrows ^project
```

```
app_init :: proc(persistent: Allocator) {
    mem = new(App_Memory, persistent)
    mem.persistent = persistent

    platform.platform_init(&mem.platform, persistent)
    render.render_init(&mem.render, persistent)
    ui.ui_init(&mem.ui, persistent)
    project.project_init(&mem.project)                     // fixes the nil-ownership hole
    editor.editor_init(&mem.editor, &mem.project, persistent)
}
```

`editor` holds a **borrow** (`^Project_Memory`), never a second owner.

**2.4 Kill the per-subsystem globals, or reduce each to one repoint.**

- *Preferred:* no global. Pass `^Render_Memory` / `^Platform_Memory` into the
  procs that need them (STYLE §2.5). Nothing to repoint on reload.
- *If a global truly earns it* (e.g. Clay's C text-measure callback cannot take
  a param), keep it but treat it strictly as a cache of a pointer (Appendix A
  rule 2), repointed in one place:

```
render_repoint   :: proc(r: ^Render_Memory)   { render_state = r }    // no alloc, no logic
platform_repoint :: proc(p: ^Platform_Memory) { platform_state = p }
```

**2.5 Reload is a single walk of the root.** Replace the cross-package chain
with one function. Adding a subsystem is one visible line here.

```
app_hot_reloaded :: proc(root: rawptr) {
    mem = (^App_Memory)(root)
    app_repoint()
}

app_repoint :: proc() {
    platform.platform_repoint(&mem.platform)
    render.render_repoint(&mem.render)
    editor.editor_repoint(&mem.editor, &mem.project)
    // reload-only side effects: clay SetCurrentContext, re-bind SDL callbacks.
    // SDL window/renderer are NOT re-created; they persist in mem.platform.
}
```

**2.6 Symmetric, nil-guarded shutdown.** The arena reclaims the struct graph in
one call; subsystems free only what the arena does not own (SDL handles, GPU
textures, the font atlas, Clay's separate buffer).

```
app_shutdown :: proc() {
    if mem == nil do return

    editor.editor_shutdown(&mem.editor)
    ui.ui_shutdown(&mem.ui)               // frees widget buffers (see Issue 2)
    render.render_shutdown(&mem.render)   // font atlas, clay buffer
    project.project_shutdown(&mem.project)
    platform.platform_shutdown(&mem.platform) // SDL_DestroyRenderer / Window / Quit

    arena_free_all(mem.persistent)        // one call reclaims the whole graph
    mem = nil
}
```

### What this buys

- One owner per state; the `project_mem`-stays-nil bug is impossible by shape.
- One repoint list; reload safety no longer depends on remembering N edits.
- One allocator story: `persistent` (survives reload) vs `temp` (per frame).
- The pooled widget store from Issue 2 now has an obvious home: a field on
  `UI_Memory`, backed by `mem.persistent`.

---

## 3. Major Issue 2 — Stable widget identity, pooled state

### The problem we are removing

Every widget is identified by a `string` literal (`"sidebar:footer:btn_project"`).
That single choice cascades into every anti-pattern STYLE §1 names:

- `ui.UI_Memory.input_states: map[string]Text_Input_State` clones keys on insert
  and frees them by hand on teardown.
- `input_state_get` **linear-scans the whole map** to recover the canonical key,
  every existing input, every frame.
- String-value identity everywhere: `focused`, `tab_first`, `tab_prev`,
  `render.pressed_id`.
- Per-frame secret allocations: `strings.concatenate` per icon button;
  `clay.ID(id)` re-hashes the same string 3–4× per widget per frame.
- **Latent use-after-realloc:** `input_state_get` returns
  `^Text_Input_State` from a `map` value and callers hold it across the frame.
  Odin map values are not address-stable; a later `map_insert` (a second input
  appearing) can rehash and invalidate that pointer.

### Target

- Replace string identity with a **stable, integer-cheap key** — a
  `distinct u32` handle (or an ID hashed once, or an enum for static widgets) —
  compared as an integer (STYLE §3.3).
- Store `Text_Input_State` in an **address-stable pool** (fixed array + free
  list) keyed by handle, not in a `map` whose values move. This fixes the
  dangling pointer and deletes the clone/scan/hand-free machinery at once.
- **Bound it** (STYLE §2.2): a fixed maximum of live inputs with an observable
  overflow signal, instead of an unbounded map.
- Hash the Clay ID **once** per widget per frame and reuse it across
  `pointer_over` / `clicked` / `UI`.

```
Widget_Id :: distinct u32                 // hashed once, compared as an int

Input_Pool :: struct {
    slots:   [MAX_INPUTS]Text_Input_State, // address-stable; ^slot is safe across a frame
    used:    [MAX_INPUTS]bool,
    free:    [dynamic]int,                 // or a fixed free list
    dropped: int,                          // overflow is observable, not silent
}

UI_Memory :: struct {
    inputs:  Input_Pool,
    focused: Widget_Id,                    // integer identity, not string compare
    // tab order tracked by Widget_Id
}
```

This depends on Issue 1: the pool lives on `UI_Memory`, backed by
`mem.persistent`.

---

## 4. Major Issue 3 — Allocator discipline and assertions

Do these while the same files are open, not after.

### 4.1 Persistent vs frame scratch, named by role

Two tiers, legible everywhere (STYLE §3.5, §4):

- `persistent` — the arena from Issue 1; survives reload; freed once.
- `context.temp_allocator` — per-frame scratch; already `free_all`'d each lap.

Persistent objects stop being individual `new()`/`make()` calls on the tracking
gpa. Anything returned in temp memory says so at the call site.

### 4.2 Assertions on the caret/byte math

`ui/input.odin` is the highest-risk code in the repo and has almost no
assertions, despite doing exactly the `remove_range` / `inject_at` /
`decode_last_rune` / `caret ± size` pointer math STYLE §2.1 says to assert.
Once state is pooled, add preconditions, postconditions, and invariants:

```
assert(caret >= 0)
assert(caret <= len(buf))
// caret lands on a UTF-8 boundary
assert(lo <= hi)                          // before remove_range(lo, hi)
```

---

## 5. Explicitly out of scope for this rewrite

Real, but do them after the roots settle — they become small local edits:

- The verbose `clay.UI(...)()` nesting and the six near-identical button blocks
  in `sidebar_frame` → table-driven (STYLE §3.2).
- `sizing_to_clay`'s dead `else` after an exhaustive enum (STYLE §2.4).
- The nested-ternary `border` color in `sidebar_frame` (STYLE §2.4).
- Missing `@(require_results)` on pure/allocating procs — mechanical.

---

## 6. Sequence

1. **De-risk SDL3:** confirm `vendor:sdl3` + font-path bindings; get one glyph on
   screen with a working `measure_text`.
2. **Persistent arena + `allocator` param** threaded through `app_init`.
3. **In-place init** for `platform` / `render` / `ui` / `editor` / `project`
   (`proc(target: ^T, ...)`), with SDL handles owned in `Platform_Memory`.
4. **`App_Memory` owns sub-states as fields**; create and own `project` there.
5. **Per subsystem:** drop the global (pass `^State`) or keep it as a
   repoint-only cache.
6. **Collapse reload** into `app_repoint`, called from `app_hot_reloaded`.
7. **Rewrite `app_shutdown`** to free the arena once; subsystems release only
   foreign handles (SDL, GPU, Clay buffer).
8. **Port the Clay command consumer** to SDL_Renderer (rects, borders via
   `SDL_RenderGeometry`, text via the chosen font system, images, scissors).
9. **Issue 2:** replace string identity with `Widget_Id` + the pooled,
   bounded, address-stable input store on `UI_Memory`.
10. **Issue 3:** finalize the two-tier allocator split and add the caret/byte
    assertions.

Keep Clay. Keep the seams. Own text. Fix identity and ownership at the root.
