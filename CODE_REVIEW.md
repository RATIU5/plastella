# Plastella Code Review

Reviewed against the codebase's own `ODIN_STYLE.md` plus general Odin idiom. The
single biggest issue in this codebase is package count, so that leads. Everything
else found (naming, dead branches, a global-state builder, zero-value gaps, a
memory-ownership bug) is still real and still cited with file/line, but none of it
matters as much as fixing the package boundaries first — several of the smaller
findings (1.2, 1.3 in the previous pass) turned out to be *symptoms* of over-splitting,
not independent bugs, and disappear once the merge below happens.

---

## 1. Package discipline — target: 2 library packages, not 10

### Current state
Excluding `vendor/clay` (third-party, untouched) and the two `main` entry points
(`host`, `release` — necessarily separate, see below), this app currently has
**10 packages** in a single-binary, single-consumer, non-reused application:

```
app  assets  config  editor  editor/editor_types  editor/areas  gfx  platform  project  ui
```

`ODIN_STYLE.md` §3.1 is explicit about the default: *"Prefer few, coarse packages
over many single-purpose ones. Packages are units of distribution, not
organization... reach for a new package only when the code is meant to be
imported, versioned, or reused independently of the rest."* None of `assets`,
`config`, `editor`, `editor_types`, `area`, `gfx`, `project`, or `ui` is imported,
versioned, or reused by anything other than this one app. They are organized by
taxonomy ("this file is about fonts, so it goes in its own `assets` folder"), not
by a genuine reuse or distribution boundary. That's 8 packages that exist for
organizational feel.

### Target: 2 library packages + the main tier

**`platform`** — keep as its own package. This is the one package with a real
justification: it is the seam that quarantines foreign APIs (SDL3, `vendor:sdl3/ttf`,
Cocoa/`objc_send`) per `ODIN_STYLE.md` §6, *"Wrap third party APIs behind a thin
seam."* `device.odin`, `input.odin`, `cursor.odin`, and the three `window_*.odin`
platform-suffixed files already form a coherent, self-contained unit around one
concept (talking to the OS and the window). Nothing here is Plastella-specific.

**`app`** — merge everything else into one coarse package: `config`, `project`,
`assets`, `gfx`, `ui`, `editor`, `editor_types`, `area`, and the existing `app`
package's own files. All of it is Plastella-specific, all of it is single-consumer,
and most of it is already tightly coupled by data (`ui` takes `^gfx.Frame`, `editor`
takes `^ui.Ctx`, `gfx` takes `^assets.Assets`) — the package boundaries between them
were never load-bearing, just filing cabinets. Odin packages are directories, but
files within one directory-package can be organized by subject with a filename
prefix so the flattening doesn't lose navigability:

```
source/app/
  app.odin                      (unchanged: lifecycle, hot-reload plumbing)
  reload_hash.odin              (pulled out of app.odin, see §2.1)
  config.odin                   (was config/config.odin)
  project.odin                  (was project/project.odin)
  assets.odin, assets_fonts.odin, assets_textures.odin, assets_ui_icons.odin
  gfx_clay.odin, gfx_colors.odin, gfx_frame.odin, gfx_interaction.odin, gfx_text_cache.odin
  ui.odin, ui_button.odin, ui_image.odin, ui_text.odin, ui_segmented_control.odin, ui_shared.odin
  editor.odin, editor_toolbar.odin, editor_statusbar.odin, editor_main_area.odin, editor_no_project.odin
```
No new `Editor`/`editor_types` split is needed once `no_project.odin` is a file in
the same package as `Editor` — the only reason that type was ever pulled into its
own package was to dodge an import cycle created by `areas` being separate (see the
previous review's 1.1–1.3). Once everything is one package, cycles are impossible by
construction and the whole problem disappears.

**`main`** — `host/` and `release/` stay exactly as they are: two directories,
each a minimal `package main`, because they are two different compiled products
(the dev hot-reload loop and the shipped standalone binary), not two takes on
the same concern. This is a structural requirement of Odin (`package main` must be
its own directory) and of the hot-reload architecture in `ODIN_STYLE.md` Appendix A,
not an organizational choice — don't try to merge these. Count them as one
conceptual tier ("the entry points") rather than two library packages.

**Net result:** 12 directories today (10 library packages + 2 mains) become 4
directories (`platform`, `app`, `host`, `release`) — 2 real library packages, which
is the "at most 3" instinct, realized as 2 + the unavoidable entry-point tier.

### The one real cost of merging, and how to pay for it
Today, `gfx`/`ui`/`assets`/`platform` cannot import `editor`/`project`/`app` — the
compiler enforces the layering because they're separate packages. Once `gfx`, `ui`,
`editor`, `assets`, `project`, and `config` are all files in one `app` package, the
compiler no longer stops a file in `gfx_clay.odin` from calling a proc defined in
`editor_toolbar.odin`; nothing about "layering" is enforced by the type system
anymore. This is a genuine trade, not a free lunch, and it's why the guide says
"prefer" coarse packages, not "always." Mitigate it with the tools you already have,
not by re-splitting:
- `ODIN_STYLE.md` §3.7 ordering: keep files ordered by dependency direction, with
  the lowest-level subject (`assets_*`) first and the highest-level (`editor_*`)
  last, so the intended layering is visible in a file listing.
  the smallest scope, per §3.9) makes an accidental reverse-call stand out on read.
- Treat it the same way you already treat `@(private = "file")`: it's cheap to add
  `@(private)` to a proc that must never be called by a higher layer, turning a
  would-be reverse-dependency into a compile error even inside one package. Reach
  for this only where a specific invariant matters (§3.11), not as blanket policy.

---

## 2. File / proc size — mixed responsibilities, not earning their place

### 2.1 `source/app/app.odin:283-345` — reflection-based layout hashing bolted onto the app lifecycle file
`layout_hash`, `app_memory_layout_hash`, and `app_assets_table_hash` are a generic
`^runtime.Type_Info` walker with zero knowledge of `App` specifically — a distinct
responsibility (generic struct-layout hashing for hot-reload safety) living inside
the file whose job is "App init/update/render/shutdown."
- **Fix:** move the `when ODIN_DEBUG` block to its own file (`reload_hash.odin`,
  same package either way, so this survives the package merge unchanged).

### 2.2 `source/ui/shared.odin:19-43` (moves to `app/ui_shared.odin`) — dead branch, `else if` chain the style guide forbids
```odin
switch type in width {
case Sizing_Auto:
    if type == .Grow {
        new_width = clay.SizingGrow()
    } else if type == .Fit {
        new_width = clay.SizingFit()
    } else {
        new_width = clay.SizingFit()
    }
case f32:
    new_width = clay.SizingFixed(type)
}
```
`Sizing_Auto` has exactly two values. The final `else` is unreachable —
`ODIN_STYLE.md` §2.4: *"Kill dead branches... Prefer switch over else-if chains."*
Duplicated verbatim for `height`.
- **Fix:**
```odin
switch type in width {
case Sizing_Auto:
    switch type {
    case .Grow: new_width = clay.SizingGrow()
    case .Fit:  new_width = clay.SizingFit()
    }
case f32:
    new_width = clay.SizingFixed(type)
}
```
or a table: `sizing_auto_to_clay := [Sizing_Auto]clay.SizingAxis{ .Grow =
clay.SizingGrow(), .Fit = clay.SizingFit() }`.

### 2.3 `source/ui/shared.odin` — `height` parameter is dead code
`sizing_to_clay(width, height := .Fit)` is called exactly once
(`source/ui/button.odin:200`), always with one argument, so `height`'s entire branch
(lines 32-43) has never been exercised. Speculative generality.
- **Fix:** delete `height` until a second caller needs it.

---

## 3. Explicitness / hidden control flow / premature abstraction

### 3.1 `source/ui/button.odin:145-215` — curried builder over hidden global state, for no reason
`button()` returns a closure (`proc(theme: BUTTON) -> (Button_State, bool)`) the
caller must invoke a second time, backed by a file-scope mutable global,
`button_pending` (line 147), and a two-assert runtime protocol (lines 157, 187).
Theme is already known at the call site (`ui.button(ctx, id, options)(.WIDE_ACTION)`),
so it could just be a fourth parameter. There is exactly one call-site shape in the
whole codebase — no second use case forces this machinery. Also, unlike the darwin
`Watch` global (`source/platform/window_darwin.odin:53`), which has a comment
explaining why global state is unavoidable there, `button_pending` has **no comment
justifying the global** — a bare violation of "always say why."
- **Fix:** collapse to one call:
```odin
button :: proc(ctx: ^Ctx, id: string, theme: BUTTON, options: Button_Options = {}) -> (Button_State, bool)
```
Delete `Button_Pending`, `button_pending`, `button_configure`, the two asserts, and
`@(deferred_none = button_end)` in favor of an explicit close at the end of `button`.

### 3.2 `source/ui/segmented_control.odin:44` — generic `$T` with exactly one call site
```odin
segmented_control :: proc(ctx: ^Ctx, id: string, active: $T, tabs: [T]Tab, ...) -> T where intrinsics.type_is_enum(T)
```
Only caller: `source/editor/toolbar.odin:75`, over `editor_types.Toolbar_Tab`.
`ODIN_STYLE.md` §3.3 permits parametric polymorphism to reuse *plain data logic
across types* — that requires actual reuse. One instantiation is premature.
- **Fix:** monomorphize to `Toolbar_Tab` directly, or leave a
  `// generic: no second use case yet` comment acknowledging the debt on purpose.

### 3.3 `source/gfx/clay.odin:429-441` — parameter shadowed by an unrelated local of the same name
```odin
err_handler :: proc "c" (err: clay.ErrorData) {
    msg := cast(string)(err.errorText.chars)[:err.errorText.length]
    err := fmt.tprintf("[clay] %v: %s\n", err.errorType, msg)   // shadows the param
    ...
}
```
Compiles, `-vet -strict-style` doesn't catch it, but a reader skimming for `err`'s
type mid-function gets the wrong one.
- **Fix:** rename to `msg_full`.

### 3.4 `source/ui/segmented_control.odin:8-13, 74-80` — an invariant enforced by asserts instead of by the type
```odin
Tab :: struct {
    id:       string,
    label:    string,
    icon:     Maybe(assets.Ui_Icons),
    disabled: bool,
}
...
if has_icon {
    assert(item.label == "")
} else {
    assert(item.label != "")
}
```
`label`/`icon` are mutually exclusive by convention, checked at render time instead
of made unrepresentable.
- **Fix:** `content: union { string, assets.Ui_Icons }` on `Tab`; switch over it, no
  asserts needed.

---

## 4. Idiomatic conventions (naming)

### 4.1 `BUTTON` and `TAB_BAR` are types named in SCREAMING_SNAKE_CASE
`source/ui/button.odin:21` — `BUTTON :: enum u8 { DEFAULT, WIDE_ACTION, SEG_CTRL_TEXT }`
`source/ui/segmented_control.odin:25` — `TAB_BAR :: enum u8 { DEFAULT }`
Types use `Ada_Case` everywhere else (`Color_State`, `Text_Key`, `App_Flag`). These
two are the only violators, and their *values* also wrongly use
`SCREAMING_SNAKE_CASE` where enum values should be `Ada_Case`.
- **Fix:** `Button_Theme :: enum u8 { Default, Wide_Action, Seg_Ctrl_Text }`,
  `Tab_Bar_Theme :: enum u8 { Default }`; update call sites.

### 4.2 `source/ui/shared.odin:3` — import aliased to its own package name
```odin
import clay "../../vendor/clay"
```
`vendor/clay` declares `package clay`, so this alias is a no-op —
`ODIN_STYLE.md` §3.1 calls this exact pattern out as noise. Every other file
imports it unaliased.
- **Fix:** `import "../../vendor/clay"`.

### 4.3 Read-only lookup tables inconsistently marked `@(rodata)`
`assets/fonts.odin:26` (`text_styles`) and `assets/textures.odin:17`
(`texture_paths`) are `@(rodata)`. The equivalent static tables elsewhere are not:
`ui/button.odin:27` (`button_styles`), `ui/segmented_control.odin:29`
(`tab_bar_styles`), `platform/cursor.odin:13` (`cursor_sdl_kind`). No stated reason
for the split.
- **Fix:** mark all three `@(rodata)` to match the `assets` precedent.

---

## 5. Error handling

No violations. Every fallible operation returns `bool` (or value + `bool`) and is
checked explicitly at the call site. No `or_return`/`or_else` chains, no hand-rolled
`Result`/`Error` types, no exception emulation outside the one documented
debug-only fail-fast in `err_handler` (`source/gfx/clay.odin:436-440`, gated by
`when ODIN_DEBUG`). Clean.

---

## 6. Zero-value design

### 6.1 `editor_types/types.odin:14-18` (moves into `app/editor.odin`) — `Editor{}` panics at first use
```odin
Editor :: struct {
    tab:         Toolbar_Tab,       // zero value .Project — fine
    status_text: string,            // zero value "" — fine
    project:     ^project.Project,  // zero value nil — NOT fine
}
```
Every render path dereferences `edtr.project.initialized` with no nil check. Only
safe because `app_init` always calls `editor_init` first.
- **Fix:** `assert(editor.project != nil)` on entry to `editor_frame`, or document
  the external-ownership contract on the field.

### 6.2 `source/ui/segmented_control.odin:8-13` — `Tab{}` panics at render time
Same fix as 3.4: a `union` field makes the zero value `nil`, handled explicitly
instead of crashing on the first render of a default `Tab`.

---

## 7. Memory / ownership

### 7.1 `source/project/project.odin:13-16` — frees a pointer it does not own, and is dead code
```odin
project_shutdown :: proc(project_mem: ^Project) {
    if project_mem == nil do return
    free(project_mem)
}
```
`Project` is never separately heap-allocated — it's a plain value field,
`app.project: project.Project`, embedded inside the one `new`'d `App`. Never
called anywhere. If it were, it would `free()` an interior pointer it didn't
allocate — the exact bug `ODIN_STYLE.md` §2.5.1 names.
- **Fix:** delete it. `Project` owns no resources (a `string` and a `bool`); it
  needs no destructor.

### 7.2 `source/ui/image.odin:8-9, 24-25` — per-frame, per-widget temp allocation with no cost comment
```odin
img_inst := new_clone(assets.image(ctx.frame.assets, img), context.temp_allocator)
img_id := strings.concatenate([]string{id, "_image"}, context.temp_allocator)
```
Not a leak (temp allocator freed at the frame boundary), but `ODIN_STYLE.md` §2.5
requires a comment justifying per-call allocation in what runs every frame per
widget. `ui/text.odin`'s `ellipsize_text` does this correctly; `image`/`icon` don't.
- **Fix:** one-line comment stating the allocation is temp-scoped, freed at frame
  end, bounded by widget count.

### 7.3 `source/app/app.odin:231` — inconsistent allocator explicitness
```odin
device := new(platform.Device)
```
vs. `source/app/app.odin:59`: `app = new(App, context.allocator)`. §3.5: *"Be
explicit at boundaries."*
- **Fix:** `new(platform.Device, context.allocator)`.

### 7.4 No unnecessary `defer` found
All six `defer` sites guard scopes with a genuine early-return exit in addition to
the natural fall-through, matching §3.4's bar for using `defer` at all.

---

## 8. Dependency direction

Currently clean: nothing under `gfx`/`ui`/`assets`/`platform` imports
`editor`/`project`/`app`. After the merge in §1, this stops being a
compiler-checked property for everything except `platform → app` (still enforced,
still one-directional) — see §1's "one real cost" note for how to keep the
discipline without the packages.

---

## Migration checklist

1. Delete `source/editor/areas/` and `source/editor/editor_types/`; fold their
   contents into `source/editor/` as plain files, `package editor`. *(Do this first
   — it removes the import cycle that justified the split, before the bigger
   merge.)*
2. Move `source/config`, `source/project`, `source/assets/*`, `source/gfx/*`,
   `source/ui/*`, `source/editor/*` into `source/app/`, one file each, `package app`.
   Rename files with subject prefixes (`assets_fonts.odin`, `gfx_clay.odin`,
   `ui_button.odin`, `editor_toolbar.odin`, ...) so the flat directory stays
   navigable. Delete the now-empty directories.
3. Fix every internal import that pointed at a now-merged package
   (`assets.X` → `X`, `gfx.Y` → `Y`, etc. — same-package references need no
   `package.` prefix at all).
4. Keep `source/platform/` exactly as is.
5. Keep `source/host/` and `source/release/` exactly as is; update their one
   import from `../app` (unchanged path, same package).
6. Apply §2–§7's fixes while files are already being touched by the move —
   cheapest time to do it.

| # | Change |
|---|--------|
| 1 | Merge `assets, config, editor, editor_types, area, gfx, project, ui` into `app`. Keep `platform` separate. |
| 2.1 | Move reflection layout-hash code out of `app.odin` into its own file. |
| 2.2/2.3 | Replace `else if` chain with exhaustive `switch`/table in `sizing_to_clay`; drop unused `height` param. |
| 3.1 | Make `theme` a direct parameter of `button()`; delete the `button_pending` global/protocol. |
| 3.2 | Monomorphize `segmented_control` or comment the generic as intentionally speculative. |
| 3.3 | Rename shadowing local `err` in `err_handler` to `msg_full`. |
| 3.4/6.2 | Replace `Tab.label`/`Tab.icon` with a `union` field. |
| 4.1 | Rename `BUTTON`→`Button_Theme`, `TAB_BAR`→`Tab_Bar_Theme`; values to `Ada_Case`. |
| 4.2 | Drop the no-op `clay` import alias. |
| 4.3 | Add `@(rodata)` to `button_styles`, `tab_bar_styles`, `cursor_sdl_kind`. |
| 6.1 | Assert `project != nil` at `editor_frame` entry, or document the ownership contract. |
| 7.1 | Delete `project_shutdown`. |
| 7.2 | Comment the per-frame temp allocations in `image`/`icon`. |
| 7.3 | Pass `context.allocator` explicitly in `app_device_create`. |

Everything else checked and found compliant: error handling (§5), `defer` usage
(§7.4), and (pre-merge) dependency direction (§8).
