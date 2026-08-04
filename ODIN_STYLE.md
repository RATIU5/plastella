# Odin Style

Coding style for Odin, written for humans and for LLMs. Inspired by [TigerStyle](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md), adapted to Odin. Where TigerStyle and idiomatic Odin disagree, lean toward idiomatic `core` code.

It serves three goals, ordered most to least important (though all VERY important).

1. **Safety.** The program does what we think it does, and crashes loudly when it does not.
2. **Performance.** Respect the machine, batch work, avoid secret costs.
3. **Developer experience.** The code reads like prose and the next person or model can extend it easily (composable).

**The prime directive.** Keep code small, composable, simple, and stupid, unless a name or comment justifies otherwise in the name of performance. No undefined behavior. No secret allocations. When you break a rule, say why in a comment on the line that breaks it. Keep the comments small and concise, and to the point. Don't add extra fluff to the comments.

## 0. How To Use This Document

- Read it once. Reread the checklist before every change. If you only have budget for one section, read section 7.
- Every rule has a rationale. If you do not understand the why, you cannot apply it well or know when to break it.
- When you deviate, leave a comment starting with the reason.
- These are defaults, not dogma. Performance critical code earns exceptions, in writing.

## 1. Philosophy

### Simplicity is the hard revision, not the first draft

Simple is not easy, and not the first thing you type. It is the third rewrite, after you understand the domain well enough to delete the accidental complexity. Spend the thinking up front.

### Composability over cleverness

Prefer small procedures that take plain data and return plain data. A procedure that owns a hidden global keyed by string is convenient once and painful forever. Defaults, reset, destroy, serialization, and iteration all fight you. A procedure that takes `state: ^Foo` composes with everything. If you are asking how to initialize a hidden thing, the design is wrong, not the caller.

### Zero technical debt, paid in cash

- Fix showstoppers while the steel is hot.
- A `// TODO` behind a disabled feature flag is fine. The door is locked so no user falls through.
- An unhandled error path that probably will not happen is not fine. Do it right the first time. The second time may never come.

### Always say why

Code shows what and how. Comments exist for why. Never delete a why.

## 2. Safety

Safety is first because a fast program that is subtly wrong is worse than useless.

### 2.1 Assertions

> Assertions detect programmer errors. Operating errors are expected and handled. Assertion failures are unexpected and must crash. Assertions downgrade catastrophic correctness bugs into loud, early liveness bugs.

- Assertions are the cheapest safety you can buy and executable documentation of your mental model. They multiply the value of fuzzing and testing.
- Calibrate density to the code. Assert where a real invariant is not otherwise expressed, and lean on the type system, slice bounds checks, and error returns for the rest. Do not pad trivial getters with ceremony asserts.
- **Assert preconditions, postconditions, and invariants** wherever the types do not. Index and pointer math on unchecked data is a bug waiting to fire. This covers byte offsets, ring buffers, parsers, and slicing.

  ```odin
  read_at :: proc(buf: []u8, byte_offset: int) -> u8 {
      assert(byte_offset >= 0)
      assert(byte_offset < len(buf))
      return buf[byte_offset]
  }

  remove_range :: proc(buf: ^[dynamic]u8, lo, hi: int) {
      assert(lo <= hi)          // precondition, range is ordered.
      assert(hi <= len(buf))    // precondition, range is in bounds.
      old_len := len(buf)
      // ...
      assert(len(buf) == old_len - (hi - lo)) // postcondition, exactly the range was removed.
  }
  ```

- **Assert the positive and the negative space.** Bugs live on the boundary between valid and invalid. Assert what you expect and reject what you do not.
- **Assert a bound before the writes it guards, not after.** A postcondition like `assert(count <= CAP)` at the end of a fill loop reports damage that already happened, and reports nothing at all in a build with `-no-bounds-check`. Assert the precondition that makes the writes safe, up front, where it can still stop them.

  ```odin
  segments := clamp(int(radius * 0.5), SEGMENTS_BASE, SEGMENTS_MAX)
  assert(segments <= SEGMENTS_MAX) // buffers are sized for exactly this, checked before the first write.
  ```

  Corollary: when the bound is already provable from a clamp, one precondition assert replaces a pile of trailing ones. Do not delete the check entirely just because it is currently unreachable, because the next edit to the clamp or the fill topology is what makes it reachable.

- **Split compound assertions.** Prefer `assert(a); assert(b)` over `assert(a && b)` so a failure points at the exact condition.
- **Assert implications on one line.** `if focused do assert(active_id != "")`.
- **Assert compile time invariants** with `#assert`. They cost nothing at runtime, catch design drift before the program runs, and are never stripped.

  ```odin
  shortcuts := [?]Shortcut{ ... }              // one entry per Action, indexed by ordinal.
  #assert(len(shortcuts) == len(Action))       // a new Action fails the build until it is mapped.
  #assert(size_of(Packet) <= 128)              // guard against silent struct bloat.
  ```

  An `[Enum]T` array is always sized to the enum and zero fills any key you forget, so a length assert on it is trivially true. To fail the build on a missing entry, index an ordinal `[?]T` table and assert its length against `len(Enum)`.

- **Pair assertions across code paths.** Assert a property where data is produced and where it is consumed. Validate a value before writing it to disk and again after reading it back. Two independent checks catch far more than one.
- **Assertions are for programmer errors, not runtime errors.** Use `assert` for what is impossible if the code is correct, and let it crash. Do not assert on expected runtime failures like a missing file, bad input, or a network hiccup, because those are handled (see 2.6). Reach for `unreachable()` or `panic` on genuinely unreachable runtime switch arms. `#panic` is compile time only, for a `when` branch that must never build.
- Strip assertions with `-disable-assert` only after you measure them as a hot path cost. Until then keep them on. Debug builds always run with assertions enabled.

### 2.2 Put a limit on everything

- Everything in reality has a bound, so encode it. Prefer a fixed capacity plus an explicit, observable signal when the bound is hit.

  ```odin
  buf:     [32]Item,   // fixed cap, extra items are dropped.
  dropped: int,        // caller reads this and handles overflow deliberately.
  ```

- Every unbounded `[dynamic]` or growing buffer needs a documented maximum enforced at the mutation site, so untrusted input like a huge request or a malicious file cannot OOM you.
- Every loop needs a provable upper bound. Where one genuinely cannot exist, like a main or event loop, assert its liveness assumptions instead.
- Prefer fixed size arrays and small array types over `[dynamic]` when a sane maximum exists. A bound you can see beats a bound you hope for.

### 2.3 Choose the type that matches the domain

- Use an explicitly sized type when the width is part of the meaning. Serialization, wire and file formats, fixed memory layouts, hardware registers, hashes, and bit manipulation all want `u8`, `u16`, `i32`, `f32`, and friends, because a portable layout cannot depend on the target word size.
- Use `int` for lengths, indices, counts, and capacities. It is the natural width of the machine and of every `core` API, so sized types there only add casts and noise.
- Treat `index`, `count`, and `size` as distinct concepts whatever the machine type (see 2.7). Use `distinct` when mixing them would be a real bug (see 3.3).

### 2.4 Control flow that is simple, explicit, and bounded

- **Recursion must be provably bounded.** The danger is unbounded stack growth, not recursion itself. Bounded recursion is fine, like an introsort that recurses only to depth `2*log2(n)` then falls back to heap sort, or a walk over a finite type graph. Make the bound obvious, prefer iterating or tail eliminating the larger side of a split so depth stays logarithmic, and note the bound in a comment on a hot path. Never recurse on unbounded external input. When in doubt an explicit stack or a fixed iteration count is easier to reason about.
- **Push ifs up, push fors down.** Keep branching in the parent and make leaf helpers do one branchless thing over a range.
- **Split compound conditions.** A wall of `a && b || c` hides unhandled cases. Break it into nested `if/else`, and ask whether the `else` also needs handling or asserting.
- **Kill dead branches.** An unreachable `else` after an exhaustive set of cases lies about the program shape. Delete it, or make the switch exhaustive with a real `case` that panics on an unexpected variant.
- **No nested ternaries.** `a || b ? b ? X : Y : Z` is unreadable and hides cases. Hoist it into a small pure helper with a `switch` that names each case. State invariants positively (`if index < length`), never as a double negative (`if !(index >= length)`).
- **Prefer `switch` over `else if` chains.** Give enum switches no `default` when you want the compiler to force you to handle every new variant. Add a `case` catch all only when it is genuinely correct.

### 2.5 Memory, no secret allocations

- **Know who owns every allocation and when it is freed.** Bracket a resource lifetime with blank lines, allocation on one side and its `defer delete` on the other, so a leak is visually obvious.
- **Prefer caller owned memory over hidden global state, once the shape is known.** Global and static variables are a fine way to rough-draft state early, when you do not yet know the shape of the problem — cheap to iterate, nothing to thread through call sites. But a global `map[string]State` that clones keys, scans linearly, and juggles `delete` on teardown is a pile of secret allocations. Once the state stabilizes, factor it into a struct the caller owns and passes as `^State`. Ownership becomes explicit, a default is plain struct initialization, and the bookkeeping is gone.
- **No per call allocation in a hot loop without a comment justifying it.** Helpers like `strings.concatenate` or `strings.clone` churn memory every call. A temp allocator makes them leak safe but they are still work. Precompute once, or state the cost is intentional and bounded.
- **Use a scoped temp allocator for scratch** and free it all at once at the boundary with `free_all(context.temp_allocator)`. Anything returned that lives in temp memory must say so at the call site, for example `// Returned string aliases temp storage, clone to keep.`
- **Name allocators by role.** Use `gpa` versus `arena` versus a temp allocator so the name tells the reader whether they must free.
- **Zero your buffers, and beware buffer bleeds.** A fixed buffer used partially must have its unused tail handled deliberately, especially before it crosses a trust or serialization boundary.

### 2.5.1 Foreign resource handles

An allocator is not the only thing that owns memory. Every `Create*` from a C library hands you a handle you must return, and the compiler will not remind you.

- **Write the `Destroy*` in the same commit as the `Create*`,** and tear down in reverse creation order. A handle derived from another handle dies first. A text engine built from a renderer is destroyed before the renderer; the library `Quit` that owns the subsystem goes last.
- **Store the handle on the owning struct the moment it is created,** not at the end of a long `init`. Otherwise an early return between creation and assignment leaks it, and the shared cleanup proc cannot see it because the field is still `nil`.

  ```odin
  // Assign as you go, so device_destroy can clean up from any early return.
  device.window = sdl.CreateWindow(...)
  if device.window == nil { device_destroy(device); return false }

  device.renderer = sdl.CreateRenderer(device.window, nil)
  if device.renderer == nil { device_destroy(device); return false }
  ```

- **Make teardown nil safe and idempotent,** because it will be called on partially constructed state from those early returns.
- **Do not `free` a handle you did not allocate,** and do not `free` an interior pointer. A subsystem struct embedded as a field of a parent struct is freed by whoever freed the parent. Its `*_shutdown` releases what it owns and nothing else.

### 2.6 Handle every error

> 92% of catastrophic failures were the result of incorrect handling of nonfatal errors.

- Handle every `or_return`, every returned `ok`, and every error enum, or ignore it loudly with a stated reason. On a failure path clean up the partial work you created, like a half written file or a half loaded library, before returning.
- **Mark pure and allocating procedures `@(require_results)`** so the compiler rejects a caller that drops the result. It is a free compile time version of handle every error.

  ```odin
  @(require_results)
  linear_search :: proc(array: $A/[]$T, key: T) -> (index: int, found: bool) { ... }
  ```

- **Use the return shorthands to keep the happy path clean.** `#optional_ok` lets a `(T, bool)` return be called for just `T` where the caller is sure, and `#optional_allocator_error` does the same for a trailing `Allocator_Error`. Neither hides the error from a caller who cares.
- Use multiple returns and `or_return` for the linear happy path. Reserve `defer` for cleanup that must run on every exit (see 3.4).
- Distinguish operating errors, expected and handled, from programmer errors, impossible if the code is correct and asserted. Do not assert a file exists. Do not gracefully return from a broken invariant.
- **Reduce return dimensionality.** No return beats `bool`, which beats `u64`, which beats `Maybe(T)`, which beats a full error union, because every extra outcome is a branch every caller must handle and that branchiness is viral. Widen the return only when the caller needs the information.

### 2.7 Off by one and the index, count, size trinity

- `index`, `count`, and `size` are distinct even when all are `int`. Index is zero based, count is one based, and size is count times the unit width in bytes.
- Converting between them is where off by one bugs breed. Name variables so the conversion is obvious, for example `byte_offset` rather than `pos`.
- Show intent on division with the right helper and comment any rounding decision.

### 2.8 Test exhaustively, including the negative space

- A test is a proc marked `@(test)` taking `t: ^testing.T`, run by `odin test` for a whole package. Tests check the mental model your assertions encode.
- **Test valid data, invalid data, and the transition between them.** The boundary is where bugs hide. Happy input alone proves little.
- **Prefer table driven tests.** List cases as data and loop, so a new case is one line.
- **Exercise the error paths.** A returned error or an `ok = false` deserves its own case.
- **Make fuzzing deterministic.** Seed the generator yourself and print the seed on failure so any run reproduces. A fuzzer shows the presence of bugs and your assertions are the oracle.
- **Keep tests hermetic and fast.** Use a temp allocator or a fresh tracking allocator so a leak in the code under test fails the test too.
- Open each test with one line stating its goal and method.

  ```odin
  import "core:testing"

  // wrap_index maps any int into the range 0 up to n and must never return an out of range value.
  @(test)
  wrap_index_stays_in_range :: proc(t: ^testing.T) {
      cases := [?]struct{ i, n, want: int }{
          {  0, 4, 0 },
          {  5, 4, 1 },
          { -1, 4, 3 },
      }
      for c in cases {
          got := wrap_index(c.i, c.n)
          testing.expectf(t, got == c.want, "wrap_index(%d, %d) = %d, want %d", c.i, c.n, got, c.want)
      }
  }
  ```

### 2.9 Debug and release builds

- Choose checks by compiler flag, not by editing code.
- **Development.** Build with `-debug -vet -strict-style` and keep assertions and the tracking allocator active.
- **Release.** Build with `-o:speed` or `-o:aggressive`. After measuring a real cost you may add `-disable-assert` to strip runtime `assert` and `-no-bounds-check` to remove slice and array bounds checks. Strip only what you measured.
- **Keep compile time checks in every build.** `-vet` and `-strict-style` cost nothing at runtime and `#assert` is never stripped.
- **Never put logic inside `assert`.** It can be compiled out, so a side effect inside it vanishes in release and changes behavior. An assertion only reads state and checks it.
- **Prefer surgical over global when removing bounds checks.** Annotate a proven hot loop with `#no_bounds_check` instead of disabling bounds checks program wide, so untrusted input keeps its guard rails.
- Ship the same assertions you developed with. Turning them off is a performance decision you earn by measuring.

## 3. Odin Specific Idioms

Odin has opinions. Lean into them, because they encode much of the above for free.

### 3.1 Naming

- Types use `Ada_Case`, like `String_Builder` and `Read_Error`.
- Enum values use `Ada_Case`, like `.Invalid_Argument` and `.End_Of_File`.
- Procedures use `snake_case`, like `reader_read_byte`.
- Variables use `snake_case`, like `byte_offset` and `read_count`.
- Constants use `SCREAMING_SNAKE_CASE`, like `DEFAULT_BUF_SIZE` and `MAX_DEPTH`.
- **Do not alias an import; the package name is already the namespace.** Write `import "core:strings"` and call `strings.to_upper`, the way `core` does. An alias that merely repeats the package name, like `import assets "../assets"`, is noise on every file. Alias only to disambiguate two packages with the same base name, or to shorten a genuinely unwieldy foreign name, and keep the alias `snake_case` and one word where possible, like `sdl`, `ttf`, `img`, `conf`.
- **Prefer few, coarse packages over many single-purpose ones.** Packages are units of distribution, not organization: a package that exists to hold one five-line file is a folder tax, not a boundary. Split code into files within a package first; reach for a new package only when the code is meant to be imported, versioned, or reused independently of the rest.
- Acronyms keep caps together, like `JSON_Value`, not `Json_Value`.
- **The package is the namespace, so name procedures for their subject.** Odin has no methods, so prefix a procedure with its subject role, like `reader_init`, `reader_destroy`, `builder_make`, and `builder_reset`, called as `bufio.reader_init`. Pair `init` with `destroy` and `make` with `delete`. Do not name a bare `init` in a package that manages more than one type.
- **Do not over abbreviate, but honor established short names.** Spell out `source` and `target` when derived names must line up, like `source_offset` and `target_offset`. Freely use the conventional short names every Odin reader knows, like `len`, `cap`, `ptr`, `buf`, `n`, `i`, `j`, `r` and `w` for read and write cursors, and `lo` and `hi`. Prefer a clear full word for a domain concept and a short name for a mechanical one.
- **Put units and qualifiers last, most significant word first.** Write `latency_ms_max`, not `max_latency_ms`, so related names group and align.
- **Prefix a helper with its caller** to show call history, like `read_sector` and `read_sector_callback`.
- **Infuse names with meaning.** Prefer `gpa` or `arena` over a bare `allocator` so the name tells the lifetime contract.
- **Callbacks go last** in a parameter list, mirroring control flow.

### 3.2 Data oriented, table driven code

- The enumerated array is one of Odin superpowers. State as data in a table indexed by an enum, with the compiler checking coverage, beats logic that switches on each case.

  ```odin
  error_message := [Error]string { ... }
  month_days    := [Month]int    { ... }
  ```

- An `[Enum]T` table lets you index by the enum value, which is safer than a raw ordinal, and the compiler sizes it to the enum. It will not warn about a forgotten key, which then reads as the zero value, so write every key. For a build time guarantee that every value is mapped, use an ordinal `[?]T` table and assert its length against `len(Enum)` (see 2.1).
- When you catch yourself copy pasting the same logic per case, drive it from a table.

  ```odin
  Extension :: struct { suffix: string, kind: File_Kind }
  extensions := [?]Extension{
      {".png", .Image},
      {".txt", .Text},
      {".odin", .Source},
  }
  for e in extensions {
      if strings.has_suffix(path, e.suffix) {
          return e.kind
      }
  }
  ```

  Shorter, one place to fix bugs, and shared rules stated once instead of N times.

### 3.3 Distinct types and unions

- Use `distinct` to stop `index`, `count`, and byte offsets from being interchangeable when it matters. Free type safety.
- When you `switch` on a union or enum, handle exactly the variants and let the compiler flag a new one. Do not paper over it with a catch all `else`.
- Prefer `Maybe(T)` over sentinel values when absent is a real state. `Maybe(u64)` beats zero means none.
- **Reach for parametric polymorphism to reuse plain data logic.** `$T`, type specialized parameters like `$A/[]$T`, and `where` clauses write one `linear_search` or `Small_Array` for every element type with zero runtime cost. Prefer a `where` clause like `where intrinsics.type_is_comparable(T)` over a runtime check. Group related overloads with a `proc{...}` group like `builder_init :: proc{...}` so callers see one name.

### 3.4 Use `defer` sparingly and deliberately

- `defer` shines when a scope has multiple exits and cleanup must run on all of them, like pairing an acquire with its release or an `or_return` heavy proc with its teardown. It keeps cleanup next to the thing it cleans up.
- `defer` makes control flow nonlinear, so the reader can no longer follow the code strictly top to bottom. When a scope has a single linear exit, write the cleanup at the end. Use `defer` for correctness across several exits, not as a reflex.

### 3.5 `context` and allocators

- `context.allocator` and `context.temp_allocator` are powerful and dangerous. Be explicit at boundaries. Pass the allocator you mean, especially for anything that outlives the current scope.
- In debug builds wrap `context.allocator` in a tracking allocator to catch leaks and bad frees. Keep it on for every debug run and watch the live allocation count.
- Per scope temp memory is a batching win (see 4). Allocate freely into temp and free it all at once.
- Library code takes an explicit `allocator` parameter and does not assume the caller temp allocator. Follow the shape `proc(..., allocator := context.allocator, loc := #caller_location)` returning an `Allocator_Error`, so the caller owns the lifetime. The temp allocator is a caller side convenience. Do not bake it into a reusable procedure whose caller may want a different lifetime.
- Application code is the counterpart: install the persistent and temp allocators once at the boundary and lean on `context`, rather than threading a persistent allocator through every subsystem. Default to `context.allocator`, and reach for a dedicated arena or pool only where one data structure earns it, not as one global funnel for every allocation.

### 3.6 Use `when` for compile time branching

- Use `when ODIN_OS == .Darwin` or `when ODIN_DEBUG` for platform and build mode differences. Compile time branches cost nothing at runtime and keep the runtime path straight. Prefer them over a runtime `if` for anything decided at build time.

### 3.7 Struct and file ordering

- Order a file top down by importance, and put `main` or the primary entry proc first.
- Odin structs hold only fields, so this ordering applies to the file, not the struct body.
- Put the primary type near the top, then its `init`, then the procedures that operate on it from most to least important.
- Lift a complex helper type out to its own top level declaration rather than burying it.
- When there is no natural order, sort alphabetically.

### 3.8 Options structs and named arguments

- Named arguments prevent positional mistakes. Two adjacent parameters of the same type that could be swapped must be passed by name at the call site or wrapped in an options struct.
- Lean on defaulted named params like `sorted := false` and `truncate := false`.
- Keep singleton dependencies like an allocator or a state handle positional and ordered from general to specific, and keep swappable values named.
- If `nil` is a valid argument, name it so the literal meaning is clear at the call site.

### 3.9 Value construction

- Prefer `x := T{...}` over `x: T = {...}`, and prefer type inference except where an explicit type aids the reader.
- Use initializers, not field by field assignment, when constructing a value.
- For large structs prefer initializing in place through an out pointer like `init :: proc(target: ^Big)` rather than returning by value, to keep pointer stability and avoid intermediate copies. In place init is viral. If one field is initialized in place, initialize the whole container in place.
- Do not duplicate variables or take aliases to state, because that is how things get out of sync. Compute or check a value close to where it is used and declare it at the smallest scope. A gap in space or time between check and use is where bugs hide.

### 3.10 Document nontrivial procedures with a doc comment

- Odin has no reserved doc comment token, but the comment block directly above a declaration, with no blank line between, is what the language server shows on hover. Treat it as the public contract. A run of `//` lines and a `/* ... */` block both work.
- For public API use a `/* ... */` block with labelled sections. Common headings are Inputs, Returns, and where useful Example and Output, plus a leading note when the proc allocates. This is the format the language server renders richly.

  ```odin
  /*
  Clones a string.

  *Allocates Using Provided Allocator*

  Inputs:
  - s: The string to be cloned
  - allocator: (default: context.allocator)

  Returns:
  - res: The cloned string
  - err: An allocator error if one occurred, `nil` otherwise
  */
  @(require_results)
  clone :: proc(s: string, allocator := context.allocator) -> (res: string, err: runtime.Allocator_Error) { ... }
  ```

- For a small internal helper a single `//` line above the proc is plenty. Reserve the full block for the public surface.
- Not every proc needs one. A small proc with an obvious name and signature is its own documentation, and `// returns the name` over `get_name` is noise that rots. Add a doc comment when the proc is mid to large, is public, or has a contract the signature cannot express.
- Write the contract, not the mechanics. Cover only what a caller cannot see. Ownership and allocation (who frees the result, which allocator, whether it aliases internal or temp storage), preconditions beyond the types, the meaning of a `nil`, empty, zero, or `ok = false` result, side effects, units, and lifetime, plus any surprising design choice. Keep the summary to one line, add only the clauses that apply, and update the comment in the same commit that changes behavior. A stale doc comment is worse than none. A comment that only restates the signature is noise. The `clone` block above is the shape to copy.

### 3.11 Visibility, and where it earns its place

- Every declaration is visible to importers by default. `@(private)` limits it to the package and `@(private="file")` limits it to the file.
- In application code you own every call site, so `@(private)` everywhere mostly adds noise. Use it sparingly to lock a specific invariant that must not be touched from another file.
- In library code the calculus flips. You publish to consumers you do not control, so hide internals with `@(private)` and export only the surface you intend to support. That is the seam idea from section 6.

## 4. Performance

- **Design for performance up front.** The 1000x wins live in the design, not the profiler. Sketch the four resources (network, disk, memory, CPU) and two axes (bandwidth, latency) on paper, aim within 90% of optimal by design, then measure.
- **Batch across boundaries.** Snapshot input once, act on the immutable snapshot, free scratch once at the boundary. Decide at the edges, act in bulk in the middle. Never react to an external event mid work, so work per unit time stays bounded.
- **Keep the CPU on straight runs.** Long, predictable passes over contiguous data beat pointer chasing and branch heavy lane changing.
- **Fix the slowest resource first, weighted by frequency.** Spend where frequency times latency is largest. A cache miss hit a million times can cost more than one fsync.
- **Make hot loops standalone and pure**, taking primitive args over a `^Struct`, so values stay in registers and redundant work is visible.
- **Only here does small, simple, stupid yield to speed**, and only with a comment, ideally a back of the envelope number, justifying the trade.

## 5. Style By The Numbers

- **Compile clean** with strict flags. Use at least `-strict-style -vet`, and consider `-vet-tabs -warnings-as-errors`. Treat every warning as an error. These catch unused variables, shadowing, bad indentation, and more.
- **`do` is for a single trailing statement, and never nests.** `if !ok do return false` reads better than four lines of braces and is idiomatic Odin. `for f in fonts do if f != nil do close(f)` is two decisions hidden on one line, which is the readability failure `-disallow-do` exists to prevent. Prefer the one line form for a single guard or a single assignment; brace it the moment a second decision appears. Do not enable `-disallow-do` unless you intend to give up the guard form too.
- **Tabs for indentation, spaces for alignment.** Indent with tabs and align continuation lines and columns with spaces so alignment survives any tab width. Enforce it with `-vet-tabs` rather than by review, so it cannot drift.
- **About 100 columns, soft.** Nothing important should hide behind a horizontal scrollbar. Wrap long signatures or calls with a trailing comma and let the formatter finish.
- **About 70 lines per procedure, soft.** There is a real cognitive cliff when a function stops fitting on a screen. Split by pushing control flow up and nonbranchy fragments down. Good shape is an inverted hourglass, few params, a simple return, a meaty middle. A flat, non-branchy proc — sequential setup, table construction, a layout tree — earns more slack than a proc full of decisions, since length there costs less than length in a proc full of decisions; the cognitive cliff comes from branching, not line count alone.
- **Braces at the end of the line** for both procs and types.
- **Declare variables at the smallest scope**, as close to first use as possible. Do not introduce a variable early or leave it lingering.
- **Comments are prose.** Capital letter, full stop, and a space after `//`. End of line comments may be terse phrases. Explain why, and explain how for tests.
- **Commit messages inform**, in the imperative, and explain why. The PR description is not in `git blame` but the commit message is.

## 6. Dependencies & Tooling

- **Minimize dependencies.** Each one adds supply chain risk, build time, and safety surface. Add one only when it clearly beats writing the small thing yourself.
- **Wrap third party APIs behind a thin seam.** Map a library enums through `[Enum]Lib_Type` tables and expose narrowed procedures, so your code depends on the seam and an implementation can be swapped without a rewrite. Quarantine foreign types and foreign naming behind the seam.
- **Standardize the toolbox.** Prefer one blessed way to build, run, and test over a drawer of ad hoc shell scripts.
- **Explicitly pass options at call sites** instead of relying on library defaults, so a future default change cannot silently alter behavior.

## 7. The Checklist (read before every change)

**Safety**

- [ ] Real invariants asserted where types and bounds checks do not, especially index, pointer, and buffer math. Positive and negative space asserted at boundaries.
- [ ] Compile time `#assert`s on enum and table lengths and struct size invariants.
- [ ] Every loop and buffer has a fixed, provable upper bound (or an asserted liveness reason), and any recursion is provably bounded.
- [ ] `int` for lengths, indices, and counts, sized types for layouts and wire formats, with `index`, `count`, and `size` kept distinct.
- [ ] Control flow simple, with ifs pushed up, no nested ternaries, no dead branches, and exhaustive enum switches.
- [ ] Pure and allocating procs marked `@(require_results)`. Every error handled or loudly ignored with a reason.

**Memory**

- [ ] No secret allocations, and every alloc has a known owner and a visible free.
- [ ] Per scope scratch uses a temp allocator, and nothing owned by temp escapes its scope unflagged.
- [ ] Global/static state used only for early rough-draft prototyping, or graduated into caller owned state once its shape is known.
- [ ] Every foreign `Create*` has its `Destroy*`, torn down in reverse order, with handles assigned as created so early returns can clean up.
- [ ] Nothing `free`s an interior pointer or a handle it did not allocate.

**Composability & Simplicity**

- [ ] Small procs over plain data, and table driven over copy pasted `switch` logic.
- [ ] Prefer passing `^State` over reaching into hidden global state.
- [ ] Few, coarse packages; files preferred over new packages for organization.
- [ ] About 70 lines per proc (more for flat, non-branchy procs), about 100 columns per line, hourglass shape.

**Odin idiom**

- [ ] Ada_Case types, Ada_Case enum values, snake_case procs and vars, SCREAMING constants. Procs named for their subject like `reader_init`, conventional short names honored.
- [ ] `defer` for cleanup across multiple exits. Linear single exit scopes clean up at the end.
- [ ] Reuse via parametric polymorphism and `where` clauses. Public API takes an explicit allocator.
- [ ] Public procs carry a doc block covering the invisible contract.
- [ ] Named args for swappable values, and an options struct for two or more params of the same type.
- [ ] Order is fields, then nested types, then procs. `init` first. Important things on top.

**Performance (earned exceptions only)**

- [ ] A back of envelope sketch done for anything on a hot path.
- [ ] Work batched at boundaries, with no reaction to external events in the middle of work.
- [ ] Hot loops are standalone, take primitive args, and are pure leaves.
- [ ] Any rule about small or simple code broken for speed is justified in a comment.

**Testing & builds**

- [ ] Tests cover valid data, invalid data, and the transition between them.
- [ ] Error paths and `ok = false` returns have their own cases.
- [ ] Fuzzers seed a printed value so failures reproduce.
- [ ] No side effecting logic lives inside `assert`.
- [ ] Release strips only the checks you measured, and `-vet` and `-strict-style` stay on.

**Say why**

- [ ] Every deviation, every nonobvious decision, has a comment starting with the reason.
- [ ] Commit message explains why, in the imperative.

> Keep trying things out, have fun, and remember that the best code is the code that is small enough to hold in your head all at once.

## Appendix A. Global & Persistent State (optional)

Read this only if your program keeps mutable state alive across a boundary that can reset it, like a hot code reload, a plugin swap, or a save and restore. Most programs do not and can skip it.

When you must have long lived global state, make it disciplined.

1. **Concentrate persistent state in one owned graph** reachable from a single root. Everything that must survive a reload or a save lives there. State that must also outlive a restart which frees that root, like OS or GPU handles (a window, a renderer), belongs one tier up in the host or loader that owns the root, passed into the app per call so there is nothing to repoint.
2. **Package globals are caches of a pointer, not owners.** If a global points at state that must persist, repoint it after any event that can zero it, in an explicit `*_reload` step. Add such a global and you must add its repoint line, or you get silent corruption.
3. **Guard layout and version compatibility across boundaries.** When state crosses a reload or serialization boundary, verify layout and version on both sides, for example hash the layout of the old and new build and refuse an incompatible swap. This is a paired assertion across the boundary.
4. **Keep `init`, `shutdown`, and `reload` symmetric and nil guarded.** Every `*_shutdown` checks `if x == nil do return` and frees exactly what its `*_init` allocated. Watch the per cycle leak count trend to zero.
5. **Keep the host and loader dumb and defensive.** Prefer reflection driven contract checks that reject a partially bound API rather than call a nil proc, so the loader does not need editing every time the contract grows.
6. **Anything you register with a third party must be re registered after a reload.** A callback or pointer you hand to a foreign library, an OS hook, or a registry is stored by them, and it keeps pointing into the module that registered it. Unload that module and the library still holds the old address. Note that relocating your own state is not sufficient, because the procedure pointer dangles by itself. Keep every registration in one list beside the `*_reload` proc so the two cannot drift. When the library takes a callback only in its `Initialize` and exposes no setter, re initializing over the same backing memory is the only way to re point it, and losing that subsystem's internal state is the price. Pay it, and guard the re initialization with a paired assertion that the new build wants the same memory size the old one allocated, per rule 3.

7. **Know which side's `context` you are running under, and measure it rather than reasoning about it.** A loader and a dynamically loaded module each link `base:runtime`, so it is tempting to assume its globals, including the default temporary allocator arena, are duplicated. Whether they actually are depends on the platform and how the module was linked, and the answer decides who is responsible for freeing scratch memory. Two things make this easy to get wrong in the head and easy to settle at runtime:

   - An exported proc with Odin calling convention receives the caller's `context` as an implicit argument, so it allocates wherever the loader points. A `proc "c"` callback has no implicit context, so a `context = runtime.default_context()` inside it builds one from the module's own globals. These are only the same arena if the underlying symbol resolved to one definition.
   - **Comparing procedure pointers across the boundary does not tell you anything.** A function reference taken inside a module goes through a binding stub, so it will not compare equal to the loader's address for the same procedure even when both reach the same code. Compare _data_ addresses instead.

   So print `context.temp_allocator.data` from both sides and compare. If the addresses match there is one arena and whoever calls `free_all` covers everyone. If they differ, the module owns its own scratch lifetime and must free it. Sample usage at the _end_ of the module's update, not the start, or the loader's `free_all` will have already run and every reading will be zero.
