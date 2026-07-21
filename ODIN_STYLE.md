# Odin Style

This is my coding style for Odin programming, written for humans and for LLMs. It is inspired by [TigerStyle](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md), adapted to Odin.

It exists to serve three goals, listed from most to least important.

1. **Safety.** The program does what we think it does, and crashes loudly when it doesn't.
2. **Performance.** We respect the machine, batch work, and avoid secret costs.
3. **Developer experience.** The code reads like prose and the next person (or model) can extend it.

**The prime directive.** _Unless a name or comment explicitly justifies it in the name of
performance, keep code small, composable, simple, and stupid._ No undefined behavior. No secret
allocations. When you break a rule, say why, in a comment, on the line that breaks it.

---

## 0. How To Use This Document

- Read the whole thing once. Read the checklist again at the end before every change.
- Every rule has a rationale. If you don't understand the "why," you can't apply the rule well, and
  you can't know when the exception is warranted.
- When you deviate, leave a comment starting with the reason.
- These are defaults, not dogma. Performance critical code earns exceptions, but it must _earn_
  them, in writing.

---

## 1. Philosophy

### Simplicity is the hard revision, not the first draft

Simple is not the same as easy, and it is not the first thing you type. It is the third rewrite,
after you understand the domain well enough to delete the accidental complexity. Spend the thinking
up front. An hour of design saves a week of debugging a hot reload state corruption bug.

### Composability over cleverness

Prefer small procedures that take plain data and return plain data. A widget that owns a hidden
global map keyed by string is convenient once and painful forever (defaults, reset, destroy,
serialization, and lists all fight you). A widget that takes `state: ^Foo` composes with everything.
When you find yourself asking "how do I initialize this hidden thing," the design is wrong, not the
caller.

### Zero technical debt, paid in cash

Fix showstoppers when the steel is hot. A `// TODO: Unimplemented` behind a `disabled = true` button
is fine. The door is locked so no user falls through it. An unhandled error path that "probably
won't happen" is not fine. Do it right the first time. The second time may never come.

### Always say why

Code shows _what_ and _how_. Comments exist for _why_. Never delete a "why."

---

## 2. Safety

Safety is the first goal because a fast program that is subtly wrong is worse than useless.

### 2.1 Assertions

> Assertions detect _programmer_ errors. Operating errors are expected and handled. Assertion
> failures are unexpected and must crash. Assertions downgrade catastrophic correctness bugs into
> loud, early liveness bugs.

Assertions are the cheapest safety you can buy, and the most underused. Treat them as executable
documentation of your mental model, and as a force multiplier when fuzzing or testing.

- **Assert preconditions, postconditions, and invariants.** Aim for an average of **at least two
  assertions per nontrivial procedure**. A procedure that operates blindly on unchecked data is a bug
  waiting to fire. Buffer and index math is the highest value place to assert. This includes caret
  offsets, ring buffers, parsers, and slicing.

  ```odin
  measure_to :: proc(text: ^[dynamic]u8, byte_offset: int) -> f32 {
      assert(byte_offset >= 0)
      assert(byte_offset <= len(text))
      // ... and, if you require it, assert byte_offset lands on a rune boundary.
  }

  delete_selection :: proc(s: ^State) {
      lo, hi := sel_lo(s), sel_hi(s)
      assert(lo <= hi)
      assert(hi <= len(s.buf))
      // ...
      assert(s.caret == s.anchor) // postcondition, no selection remains.
  }
  ```

- **Assert the positive AND the negative space.** The interesting bugs live on the boundary between
  valid and invalid. Assert what you expect _and_ reject what you don't.

- **Split compound assertions.** Prefer `assert(a); assert(b)` over `assert(a && b)`, because a
  failure points at the exact condition.

- **Assert implications on one line.** `if focused do assert(active_id != "")`.

- **Assert compile time invariants** with `#assert`. These cost nothing at runtime and catch design
  drift before the program runs.

  ```odin
  #assert(len(Key) == len(key_to_backend))   // the mapping table covers every enum value.
  #assert(size_of(Hot_State) <= 128)          // guard against silent struct bloat.
  ```

  Any time you build an `[Enum]Backend_Type` mapping table, guard it with a length `#assert` so a new
  enum value can never be silently unmapped.

- **Pair assertions across code paths.** Assert a property where data is produced _and_ where it is
  consumed. For example, validate a value right before writing it to disk and again immediately after
  reading it back. Two independent checks on the same invariant catch far more than one.

- **Assertions are for programmer errors, not runtime errors.** Use `assert` for "this is impossible
  if the code is correct" and let it crash. Do **not** assert on expected runtime failures (missing
  file, bad user input, network hiccup), because those are handled (see §2.6). Reach for `panic` or
  `#panic` on genuinely unreachable switch arms.

- Assertions can be stripped with `-disable-assert` if you ever measure them as a hot path problem.
  Until you've measured, keep them on. Debug builds should always run with assertions enabled.

### 2.2 Put a limit on everything

Everything in reality has a bound, so encode it. The best pattern is a **fixed capacity plus an
explicit, observable signal when the bound is hit**.

```odin
char_buf:      [32]rune,   // fixed cap, large inputs truncate.
chars_dropped: int,        // caller reads this and handles overflow deliberately.
```

- Every unbounded `[dynamic]` or growing buffer should have a documented maximum and enforce it at
  the mutation site, so untrusted input (a huge paste, a malicious file) can't OOM you.
- Every loop must have a provable upper bound. Where a loop genuinely can't (a main or event loop),
  assert its liveness assumptions instead.
- Prefer fixed size arrays and small array types over `[dynamic]` when a sane maximum exists. A bound
  you can see beats a bound you hope for.

### 2.3 Use explicitly sized types

Use `u8`, `u16`, `i32`, `f32`. Avoid `int` and `uint` (their width is architecture dependent) except
where an API forces it. Slice lengths and indices from `core` are naturally `int`, and interoperating
with them as `int` is fine. Even then, treat `index`, `count`, and `size` as _distinct concepts_ that
happen to share a machine type (see §2.7).

### 2.4 Control flow that is simple, explicit, and bounded

- **No recursion in runtime or hot paths.** Bounded, nonrecursive control flow keeps stack usage
  predictable. Recursion can be acceptable when it runs only in debug or only at startup, is provably
  bounded (for example, walking a finite type graph with a `seen` set), and the rationale is
  documented. That is how you earn a recursion exception. It must be bounded, off the hot path, and
  explained.

- **Push `if`s up, push `for`s down.** Keep branching in the parent procedure, and make leaf helpers
  do one branchless thing over a range. Centralize control flow in one place, and let the rest be
  pure.

- **Split compound conditions.** A wall of `a && b || c` hides unhandled cases. Break it into nested
  `if/else`. And when you write an `if`, ask whether the `else` also needs handling or asserting, so
  you cover both the positive and negative space.

- **Kill dead branches.** An unreachable `else` after an exhaustive set of cases is a lie about the
  program's shape. Delete it, or make the switch exhaustive with a real `case:` that `panic`s on an
  unexpected variant.

- **No nested ternaries.** A line like `a || b ? b ? X : Y : Z` is unreadable and hides cases. Hoist
  it into a small pure helper with a `switch` that names each case. State invariants _positively_
  (`if index < length`), never as a double negative (`if !(index >= length)`).

- **Prefer `switch` over `else if` chains**, and give enum switches no `default` when you _want_ the
  compiler to force you to handle every new variant. This is one of Odin's best safety features, so
  use it. Add an explicit `case:` only when a catch all is genuinely correct.

### 2.5 Memory, no secret allocations

- **Know who owns every allocation and when it's freed.** Use blank lines to bracket a resource's
  lifetime, with allocation on one side and its `defer delete` on the other, so a leak is visually
  obvious.

- **Prefer static or caller owned memory over hidden global maps.** A `map[string]State` that lazily
  `clone`s keys, does a linear scan, and juggles `delete` on teardown is a pile of secret allocations
  and awkward lifecycle. Letting the caller own the `State` and passing `^State` makes ownership
  explicit, turns "set a default" into plain struct initialization, and deletes the bookkeeping. Keep
  string identity only for the things that truly need it.

- **No per frame or per call allocation in hot paths without a comment justifying it.** Helpers like
  `strings.concatenate` or `strings.clone` inside a hot loop churn memory every call. A per frame temp
  allocator makes them safe from leaks, but they are still work. Either precompute once, or leave a
  comment stating the cost is intentional and bounded.

- **Use a per frame or per request temp allocator for scratch**, and free it all at once at the
  boundary (`free_all(context.temp_allocator)`). Anything returned from a proc that lives in temp
  memory must say so at the call site, for example `// Returned string aliases temp storage, clone to keep.`

- **Name allocators by role**, not just type. Use `gpa: mem.Allocator` versus `arena: mem.Allocator`
  versus a temp allocator. The name tells the reader whether they must free.

- **Zero your buffers, and beware buffer bleeds.** A fixed buffer used partially must have its unused
  tail handled deliberately, especially before it crosses a trust or serialization boundary.

### 2.6 Handle every error

> "92% of catastrophic failures were the result of incorrect handling of nonfatal errors."

- Every `or_return`, every returned `ok: bool`, every error enum must be handled or explicitly,
  loudly ignored with a stated reason. On a failure path, clean up the partial work you created
  (remove the half written file, unload the half loaded library) before returning.

- Use Odin's multiple returns and `or_return` for the linear happy path. Reserve `defer` for cleanup
  that must run on _every_ exit (see §3.4).

- Distinguish **operating errors** (expected, like a missing file or a resource being written) which
  you _handle_, from **programmer errors** (impossible if the code is correct) which you _assert_.
  Don't `assert` a file exists. Don't gracefully `return` from a broken invariant.

- **Reduce return dimensionality.** `void` beats `bool` beats `u64` beats `Maybe(T)` beats a full
  error union, because every extra outcome is a branch every caller must handle, and that branchiness
  is viral. Only widen the return type when the caller genuinely needs the information.

### 2.7 Off by one and the index, count, size trinity

`index`, `count`, and `size` are semantically distinct even when all are `int`. Index is zero based,
count is one based, and size is count times the unit width in bytes. Converting between them is where
off by one bugs breed, so name variables to make the conversion obvious (use `byte_offset`, not
`pos`, when it is a byte offset). Show intent on division with the right helper, and comment any
rounding decision.

---

## 3. Odin Specific Idioms

Odin has opinions. Lean into them, because they encode much of the above for free.

### 3.1 Naming

Follow the official convention.

| Thing        | Case                          | Example                             |
| ------------ | ----------------------------- | ----------------------------------- |
| Types        | `Ada_Case`                    | `Text_Input_State`, `Render_Memory` |
| Enum values  | `Ada_Case`                    | `.Engaged_Hover`, `.Level_Editor`   |
| Procedures   | `snake_case`                  | `input_handle_keys`                 |
| Variables    | `snake_case`                  | `caret_byte`, `scroll_x`            |
| Constants    | `SCREAMING_SNAKE_CASE`        | `SIDEBAR_MIN`, `DBL_CLICK_SEC`      |
| Import names | `snake_case`, prefer one word | `import ui "../ui"`                 |
| Acronyms     | keep caps together            | `UI_Memory`, not `Ui_Memory`        |

Be consistent. In particular, note the following.

- **Type names are always `Ada_Case`.** Don't use `SCREAMING_SNAKE` for a type (for example, an enum
  used as a "theme" or "kind"), because a SCREAMING name reads as a constant and misleads. Prefer
  `Input_Theme` over `INPUT`.
- **Enum values are `Ada_Case`.** The sanctioned exception is a one to one port of a foreign API (for
  example, mirroring a C library's `SCREAMING` keycodes). Keep the foreign casing so the mapping is
  obvious, and comment that intent at the enum.

More naming discipline worth adopting.

- **Don't abbreviate** except conventional loop or math indices. `source` and `target` beat `src` and
  `dst` because derived names (`source_offset`, `target_offset`) line up and read symmetrically.
- **Put units and qualifiers last, with the most significant word first.** Write `latency_ms_max`,
  not `max_latency_ms`, so related names group and align.
- **Prefix a helper with its caller** to show call history, as in `read_sector` and
  `read_sector_callback`.
- **Infuse names with meaning.** Prefer `gpa` or `arena` over a bare `allocator`, because the name
  should tell the reader the lifetime contract.
- **Callbacks go last** in a parameter list, which mirrors control flow, since they are invoked last.

### 3.2 Data oriented, table driven code

The enumerated array is one of Odin's superpowers. State as _data_ in a table, indexed by an enum,
with the compiler checking coverage, beats logic that switches on each case.

```odin
button_styles   := [Button_Theme]Button_Style { ... }
key_to_backend  := [Key]Backend_Key { ... }
```

- Guard every enum to array table with `#assert(len(Table) == len(Enum))` and rely on Odin erroring
  on missing keys where it can.
- Whenever you catch yourself copy pasting the same block of logic per case (six near identical
  buttons, one per tab), drive it from a table instead.

  ```odin
  Tab_Button :: struct { id: string, icon: Icon, tab: Tab }
  tab_buttons := [?]Tab_Button{ ... }
  for b in tab_buttons {
      if button(b.id, b.icon, selected = active_tab == b.tab) {
          active_tab = b.tab
      }
  }
  ```

  Shorter, one place to fix bugs, and shared rules are stated once instead of N times.

### 3.3 Distinct types and unions

- Use `distinct` to stop `index`, `count`, and byte offsets from being interchangeable when it
  matters. It's free type safety.
- When you `switch` on a union or enum, handle exactly the variants and let the compiler tell you when
  a variant is added. Don't paper over it with a catch all `else`.
- Prefer `Maybe(T)` over sentinel values when "absent" is a real state. `?u64` beats "0 means none."

### 3.4 Use `defer` sparingly and deliberately

Use `defer` only when there are _multiple_ exits from a scope and cleanup must run on all of them.
Don't `defer` when there's a single, linear exit, because it makes code nonlinear and harder to read
for no benefit. Defer has a cost. The reader can no longer follow the code top to bottom.

### 3.5 `context` and allocators

- The implicit `context.allocator` and `context.temp_allocator` are powerful and dangerous. Be
  explicit at boundaries. Pass the allocator you mean, especially for anything that outlives the
  current scope.
- In debug builds, wrap `context.allocator` in a tracking allocator to catch leaks and bad frees. It
  is your fuzzer for memory bugs, so keep it on for every debug run and watch the live allocation
  count.
- Per scope temp memory is a batching win (§4). Allocate freely into temp, then free it all at once.
  This is the control plane and data plane split applied to memory.

### 3.6 Use `when` for compile time branching

Use `when ODIN_OS == .Darwin` or `when ODIN_DEBUG` for platform and build mode differences. Compile
time branches cost nothing at runtime and keep the runtime path straight. Prefer them over a runtime
`if` for things that are decided at build time.

### 3.7 Struct and file ordering

Order a file top down by importance, because that's how it's read, and put `main` (or the primary
entry proc) first. For structs, order them as **fields, then nested types, then procedures** (with
`init` first). Put the primary type near the top of its file, and promote a complex nested type to a
top level type. When there's no natural order, sort alphabetically (big endian names make this
pleasant).

### 3.8 Options structs and named arguments

Odin's named arguments prevent positional mistakes. Two adjacent parameters of the same type that
could be swapped _must_ be passed by name at the call site, or wrapped in an options struct. Lean on
defaulted named params (`disabled := false`, `selected := false`). Keep singleton dependencies (an
allocator, a state handle) positional and ordered from general to specific, and keep swappable values
named. If `nil` is a valid argument, name it so the meaning of the literal is clear at the call site.

### 3.9 Value construction

- Prefer `x := T{...}` over `x: T = {...}`, and prefer type inference (`s := load(...)`) except where
  an explicit type genuinely aids the reader.
- Use initializers, not field by field assignment, when constructing a value.
- For large structs, prefer initializing in place through an out pointer (`init :: proc(target: ^Big)`)
  rather than returning by value, to assume pointer stability and avoid intermediate copies. In place
  init is viral. If one field is initialized in place, initialize the whole container in place.
- Don't duplicate variables or take aliases to state, because that's how things get out of sync.
  Compute or check a value close to where it's used, and declare it at the smallest possible scope. A
  gap in space or time between check and use is where bugs hide.

### 3.10 Document nontrivial procedures with a doc comment

Odin has no special doc comment syntax. The plain line comment block immediately above a
declaration, with no blank line between, is what the editor language server (OLS) shows on hover and
completion. Treat that comment block as the procedure's public contract.

Not every proc needs one. A small proc with an obvious name and an obvious signature is its own
documentation, and a comment like `// returns the name` above `get_name` is noise that rots. Add a
doc comment when the proc is mid to large sized, is part of a package's public surface, or has a
contract the signature cannot express on its own.

Write the contract, not the mechanics. Cover the parts a caller cannot see.

- **Ownership and allocation.** Who frees the result, which allocator it uses, and whether a returned
  slice or string aliases internal or temporary storage.
- **Preconditions.** What the caller must guarantee before calling, beyond what the types enforce.
- **Return meaning.** What a `nil`, empty, zero, or `ok = false` result means.
- **Side effects.** Global or persistent state it mutates, input it drains, or hardware it touches.
- **Units and lifetime.** Milliseconds versus seconds, bytes versus runes, and how long a returned
  handle stays valid.
- **Why.** Any surprising design choice, in the spirit of section 1.

Keep the summary to one line that says what the proc does, then add only the clauses above that
actually apply. Match the prose style in section 5. Keep the comment directly above the proc so the
editor associates them, and update it in the same commit that changes the behavior, because a stale
doc comment is worse than none.

Bad, a comment that only restates the signature.

```odin
// Adds a and b and returns the result.
add :: proc(a, b: int) -> int { return a + b }
```

Good, a comment that documents the invisible contract.

```odin
// get_clipboard borrows raylib's internal buffer. The returned string is valid only until the
// next clipboard call, so clone it to keep it past this frame.
get_clipboard :: proc() -> string { ... }

// input_state_get returns the state for id, creating and seeding it on first use. The returned
// pointer is owned by the ui memory and stays stable until shutdown. It is not safe to hold across
// a reload unless the caller fetches it again after the pointer graph is repointed.
input_state_get :: proc(id: string) -> ^Text_Input_State { ... }
```

---

## 4. Performance

> "The lack of back of the envelope performance sketches is the root of all evil."

- **Design for performance up front**, when the 1000× wins are still available and free. You can't
  profile a design that doesn't exist yet, so sketch the four resources (network, disk, memory, CPU)
  and their two axes (bandwidth, latency) on the back of an envelope. Aim to land within 90% of
  optimal by design, then measure.

- **Batch across boundaries.** Snapshot external input once, act against the immutable snapshot, and
  free scratch memory once at the boundary. This separation of control plane and data plane, where you
  decide at the edges and act in bulk in the middle, is what lets you keep dense assertions without
  losing speed. Never react directly to an external event in the middle of work. Run at your own pace
  so you stay in control and can bound the work per unit time.

- **Don't make the CPU context switch.** Give it long, predictable runs of work over contiguous data.
  Straight, cache friendly passes over tables beat pointer chasing and lane changing.

- **Optimize the slowest resource first, weighted by frequency.** A cache miss hit a million times can
  cost more than one fsync. Spend effort where the frequency times latency product is largest.

- **Extract hot loops into standalone procs with primitive args**, no `self` or struct receiver, so
  the compiler can keep values in registers and a human can spot redundant work. Keep leaf functions
  pure.

- **This is the only section where "small, simple, stupid" yields to speed**, and only with a comment
  and, ideally, a back of the envelope number justifying the trade.

---

## 5. Style By The Numbers

- **Compile clean** with strict flags. At minimum use `-strict-style -vet`, and consider
  `-vet-tabs -disallow-do -warnings-as-errors`. Treat every warning as an error, because warnings are
  bugs you haven't hit yet. These flags catch unused variables, shadowing, bad indentation, and more.
- **Tabs for indentation, spaces for alignment.** Indent with tabs, and align continuation lines and
  columns with spaces so alignment survives any tab width.
- **About 100 columns, soft limit.** Nothing important should hide behind a horizontal scrollbar. Wrap
  long signatures or calls with a trailing comma and let the formatter do the rest.
- **About 70 lines per procedure, soft.** There's a real cognitive cliff when a function stops fitting
  on a screen. Split by pushing control flow up and pushing nonbranchy fragments down. Good function
  shape is an inverted hourglass, with few params, a simple return, and a meaty middle.
- **Braces at the end of the line**, for both procs and types.
- **Declare variables at the smallest possible scope**, as close to first use as possible. Don't
  introduce a variable before it's needed or leave it lingering after.
- **Comments are prose.** Use a capital letter, a full stop, and a space after `//`. Comments at the
  end of a line may be terse phrases. Explain _why_, and explain _how_ for tests (state the goal and
  methodology at the top).
- **Commit messages inform**, in the imperative, and explain _why_. The PR description isn't in `git
blame`, but the commit message is.

---

## 6. Dependencies & Tooling

- **Minimize dependencies.** Each one adds supply chain risk, build time, and safety surface. Add a
  dependency only when it clearly beats writing the small thing yourself.
- **Wrap third party APIs behind a thin seam.** Map a library's enums through `[Enum]Lib_Type` tables
  and expose narrowed procedures, so your app never touches the library directly and the backend stays
  swappable. Quarantine foreign types and foreign naming behind that seam.
- **Standardize the toolbox.** Prefer one blessed way to build, run, and test over a drawer of ad hoc
  shell scripts. A small, shared toolbox is simpler to operate as the team and the range of tastes
  grow.
- **Explicitly pass options at call sites** instead of relying on library defaults, so a future
  default change can't silently alter behavior.

---

## 7. Global & Persistent State

Global mutable state is sometimes unavoidable, such as a plugin or hot reload boundary, or a
singleton subsystem. When you must have it, make it disciplined.

1. **Concentrate persistent state in one owned graph**, reachable from a single root (for example, an
   `App_Memory` struct). Everything that must survive across a reload, a save, or a subsystem restart
   lives there.
2. **Package globals are caches of a pointer, not owners.** If a global holds state that must persist,
   it must be repointed after any event that can zero it (a DLL swap), in an explicit `*_reload` step.
   Add a global holding state and you must add its repoint line, or you get silent corruption.
3. **Guard layout and version compatibility across boundaries.** When state crosses a reload or
   serialization boundary, verify the layout and version on both sides (for example, hash the memory
   layout of the old and new build and refuse an incompatible hot swap). This is a paired assertion
   across the boundary, so don't defeat it.
4. **Keep `init`, `shutdown`, and `reload` symmetric and nil guarded.** Every `*_shutdown` checks
   `if x == nil do return` and frees exactly what its `*_init` allocated. Preserve that symmetry. A
   leak report on every cycle is a number you should watch trend to zero.
5. **Keep the host and loader dumb and defensive.** Prefer reflection driven contract checks (reject a
   partially bound API rather than call a nil proc) so the loader doesn't need editing every time the
   contract grows.

---

## 8. The Checklist (read before every change)

**Safety**

- [ ] Two or more assertions in each nontrivial proc, with preconditions, postconditions, and
      invariants stated.
- [ ] Positive _and_ negative space asserted at boundaries between valid and invalid.
- [ ] Compile time `#assert`s on enum and table lengths and struct size invariants.
- [ ] Every loop and buffer has a fixed, provable upper bound (or an asserted liveness reason).
- [ ] Explicitly sized types, with `index`, `count`, and `size` kept semantically distinct.
- [ ] Control flow is simple, with no runtime recursion, `if`s pushed up, no nested ternaries, no dead
      branches, and exhaustive enum switches.
- [ ] Every error handled or loudly, deliberately ignored with a reason.

**Memory**

- [ ] No secret allocations, and every alloc has a known owner and a visible free.
- [ ] Per scope scratch uses a temp allocator, and nothing owned by temp escapes its scope unflagged.
- [ ] Persistent state lives in one owned graph and is repointed after any reload.
- [ ] Caller owned state preferred over hidden global maps.

**Composability & Simplicity**

- [ ] Small procs over plain data, and table driven over copy pasted `switch` logic.
- [ ] Prefer passing `^State` over reaching into a hidden singleton.
- [ ] About 70 lines per proc, about 100 columns per line, hourglass shape.

**Odin idiom**

- [ ] Ada_Case types, Ada_Case enum values, snake_case procs and vars, SCREAMING constants.
- [ ] `defer` only for cleanup with multiple exits.
- [ ] Named args for swappable values, and an options struct for two or more params of the same type.
- [ ] Order is fields, then nested types, then procs. `init` first. Important things on top.

**Performance (earned exceptions only)**

- [ ] A back of envelope sketch done for anything on a hot path.
- [ ] Work batched at boundaries, with no reaction to external events in the middle of work.
- [ ] Hot loops are standalone, take primitive args, and are pure leaves.
- [ ] Any rule about small or simple code broken for speed is justified in a comment.

**Say why**

- [ ] Every deviation, every nonobvious decision, has a comment starting with the reason.
- [ ] Commit message explains _why_, in the imperative.

> Keep trying things out, have fun, and remember that the best code is the code that's small enough to
> hold in your head all at once.
