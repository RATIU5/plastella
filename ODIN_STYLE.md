# Odin Style

This is my coding style for Odin programming, written for humans and for LLMs. It is inspired by [TigerStyle](https://github.com/tigerbeetle/tigerbeetle/blob/main/docs/TIGER_STYLE.md), adapted to Odin. Where TigerStyle and idiomatic Odin disagree, this document leans toward the Odin `core` standard library, which is the reference for what high quality Odin actually looks like. TigerStyle supplies the safety mindset, and the standard library supplies the idiom.

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
up front. An hour of design saves a week of debugging a state corruption bug.

### Composability over cleverness

Prefer small procedures that take plain data and return plain data. A procedure that owns a hidden
global keyed by string is convenient once and painful forever (defaults, reset, destroy,
serialization, and iteration all fight you). A procedure that takes `state: ^Foo` composes with
everything. When you find yourself asking "how do I initialize this hidden thing," the design is
wrong, not the caller.

### Zero technical debt, paid in cash

Fix showstoppers when the steel is hot. A `// TODO: Unimplemented` behind a disabled feature flag is
fine. The door is locked so no user falls through it. An unhandled error path that "probably won't
happen" is not fine. Do it right the first time. The second time may never come.

### Always say why

Code shows _what_ and _how_. Comments exist for _why_. Never delete a "why."

---

## 2. Safety

Safety is the first goal because a fast program that is subtly wrong is worse than useless.

### 2.1 Assertions

> Assertions detect _programmer_ errors. Operating errors are expected and handled. Assertion
> failures are unexpected and must crash. Assertions downgrade catastrophic correctness bugs into
> loud, early liveness bugs.

Assertions are the cheapest safety you can buy, and they are executable documentation of your mental
model, as well as a force multiplier when fuzzing or testing.

Calibrate the density to the code rather than chasing a per-proc quota. The standard library reaches
for `assert` where a real invariant is not otherwise expressed, and leans on the type system, slice
bounds checks, and error returns for the rest. Do the same: assert index and buffer math, ring
buffers, parsers, hand rolled offsets, and anything that has crossed an `unsafe`, `transmute`, or
foreign boundary, and don't pad trivial getters with ceremony asserts.

- **Assert preconditions, postconditions, and invariants** wherever the types don't already. A
  procedure that does nontrivial index or pointer math on unchecked data is a bug waiting to fire, so
  assert there. This includes byte offsets, ring buffers, parsers, and slicing.

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

- **Assert the positive AND the negative space.** The interesting bugs live on the boundary between
  valid and invalid. Assert what you expect _and_ reject what you don't.

- **Split compound assertions.** Prefer `assert(a); assert(b)` over `assert(a && b)`, because a
  failure points at the exact condition.

- **Assert implications on one line.** `if focused do assert(active_id != "")`.

- **Assert compile time invariants** with `#assert`. These cost nothing at runtime and catch design
  drift before the program runs. Note that `#assert` is compile time only and is never stripped from
  a build, unlike the runtime `assert`.

  ```odin
  shortcuts := [?]Shortcut{ ... }              // one entry per Action, indexed by ordinal.
  #assert(len(shortcuts) == len(Action))       // a new Action fails the build until it is mapped.
  #assert(size_of(Packet) <= 128)              // guard against silent struct bloat.
  ```

  An `[Enum]T` array is always sized to the enum and quietly zero fills any key you forget, so a
  length assert on it is trivially true. When you need the build to fail on a missing entry, index an
  ordinal `[?]T` table and assert its length against `len(Enum)` as above.

- **Pair assertions across code paths.** Assert a property where data is produced _and_ where it is
  consumed. For example, validate a value right before writing it to disk and again immediately after
  reading it back. Two independent checks on the same invariant catch far more than one.

- **Assertions are for programmer errors, not runtime errors.** Use `assert` for "this is impossible
  if the code is correct" and let it crash. Do **not** assert on expected runtime failures (missing
  file, bad user input, network hiccup), because those are handled (see §2.6). Reach for
  `unreachable()` or `panic` on genuinely unreachable runtime switch arms (`#panic` is compile time
  only, for a `when` branch that must never build).

- Assertions can be stripped with `-disable-assert` if you ever measure them as a hot path problem.
  Until you've measured, keep them on. Debug builds should always run with assertions enabled.

### 2.2 Put a limit on everything

Everything in reality has a bound, so encode it. The best pattern is a **fixed capacity plus an
explicit, observable signal when the bound is hit**.

```odin
buf:     [32]Item,   // fixed cap, extra items are dropped.
dropped: int,        // caller reads this and handles overflow deliberately.
```

- Every unbounded `[dynamic]` or growing buffer should have a documented maximum and enforce it at
  the mutation site, so untrusted input (a huge request, a malicious file) can't OOM you.
- Every loop must have a provable upper bound. Where a loop genuinely can't (a main or event loop),
  assert its liveness assumptions instead.
- Prefer fixed size arrays and small array types over `[dynamic]` when a sane maximum exists. A bound
  you can see beats a bound you hope for.

### 2.3 Choose the type that matches the domain

Reach for the explicitly sized type when the width is part of the meaning: serialization, wire and
file formats, fixed memory layouts, hardware registers, hashes, and bit manipulation all want `u8`,
`u16`, `i32`, `f32`, and friends, because a portable layout cannot depend on the target word size.

For lengths, indices, counts, and capacities, `int` is the idiomatic and correct choice, and the one
the standard library uses everywhere (`len`, indexing, `mem.set(..., len: int)`). It is the natural
width of the machine and of every `core` API, so fighting it with sized types just adds casts and
noise. Prefer `int` there and save the sized types for the layouts that truly need them.

Whatever the machine type, treat `index`, `count`, and `size` as _distinct concepts_ (see §2.7), and
use `distinct` when mixing them up would be a real bug (see §3.3).

### 2.4 Control flow that is simple, explicit, and bounded

- **Recursion must be provably bounded.** The danger is unbounded stack growth, not recursion itself.
  Bounded recursion is fine and common in high quality Odin: `core:sort` runs an introsort that
  recurses only to a depth of `2*log2(n)` and switches to heap sort past that, and reflection walks a
  finite type graph. When you recurse, make the bound obvious, prefer iterating (or tail eliminating)
  the larger side of a split so the depth is logarithmic, and note the bound in a comment on a hot
  path. Never recurse on unbounded external input. When in doubt, an explicit stack or a fixed
  iteration count is easier to reason about than deep recursion.

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

- **Prefer caller owned memory over hidden global state.** A global `map[string]State` that lazily
  `clone`s keys, does a linear scan, and juggles `delete` on teardown is a pile of secret allocations
  and an awkward lifecycle. Letting the caller own the `State` and passing `^State` makes ownership
  explicit, turns "set a default" into plain struct initialization, and deletes the bookkeeping.

- **No per call allocation in a hot loop without a comment justifying it.** Helpers like
  `strings.concatenate` or `strings.clone` inside a hot loop churn memory every call. A temp allocator
  makes them safe from leaks, but they are still work. Either precompute once, or leave a comment
  stating the cost is intentional and bounded.

- **Use a scoped temp allocator for scratch**, and free it all at once at the boundary
  (`free_all(context.temp_allocator)`). Anything returned from a proc that lives in temp memory must
  say so at the call site, for example `// Returned string aliases temp storage, clone to keep.`

- **Name allocators by role**, not just type. Use `gpa: mem.Allocator` versus `arena: mem.Allocator`
  versus a temp allocator. The name tells the reader whether they must free.

- **Zero your buffers, and beware buffer bleeds.** A fixed buffer used partially must have its unused
  tail handled deliberately, especially before it crosses a trust or serialization boundary.

### 2.6 Handle every error

> "92% of catastrophic failures were the result of incorrect handling of nonfatal errors."

- Every `or_return`, every returned `ok: bool`, every error enum must be handled or explicitly,
  loudly ignored with a stated reason. On a failure path, clean up the partial work you created
  (remove the half written file, unload the half loaded library) before returning.

- **Mark pure and allocating procedures `@(require_results)`.** This is one of the standard library's
  most used safety idioms (thousands of call sites), and it makes the compiler reject a caller that
  drops the result. Any proc whose only effect is its return value, and any proc that hands back an
  allocation or an error the caller must inspect, should carry it. It is a free, compile time version
  of "handle every error."

  ```odin
  @(require_results)
  linear_search :: proc(array: $A/[]$T, key: T) -> (index: int, found: bool) { ... }
  ```

- **Lean on Odin's return-shorthands to keep the happy path clean.** `#optional_ok` lets a
  `(T, bool)` return be called for just `T` where the caller is sure, and `#optional_allocator_error`
  does the same for the trailing `Allocator_Error`. Both are stdlib conventions that reduce caller
  branchiness without hiding the error from callers who do care.

- Use Odin's multiple returns and `or_return` for the linear happy path. Reserve `defer` for cleanup
  that must run on _every_ exit (see §3.4).

- Distinguish **operating errors** (expected, like a missing file or a resource being written) which
  you _handle_, from **programmer errors** (impossible if the code is correct) which you _assert_.
  Don't `assert` a file exists. Don't gracefully `return` from a broken invariant.

- **Reduce return dimensionality.** No return value beats `bool`, which beats `u64`, which beats
  `Maybe(T)`, which beats a full error union, because every extra outcome is a branch every caller
  must handle, and that branchiness
  is viral. Only widen the return type when the caller genuinely needs the information.

### 2.7 Off by one and the index, count, size trinity

`index`, `count`, and `size` are semantically distinct even when all are `int`. Index is zero based,
count is one based, and size is count times the unit width in bytes. Converting between them is where
off by one bugs breed, so name variables to make the conversion obvious (use `byte_offset`, not
`pos`, when it is a byte offset). Show intent on division with the right helper, and comment any
rounding decision.

### 2.8 Test exhaustively, including the negative space

Odin ships a test runner in `core:testing`. A test is a proc marked `@(test)` that takes
`t: ^testing.T`, and `odin test` runs every one in a package. Tests check the mental model that your
assertions encode, so they belong next to the safety story.

- **Test valid and invalid data, and the transition between them.** The boundary where data crosses
  from valid to invalid is where bugs hide, exactly as in section 2.1. A test that only feeds happy
  input proves very little.
- **Prefer table driven tests.** List the cases as data and loop over them, so a new case is one line
  and the intent stays readable.
- **Exercise the error paths.** Most catastrophic failures come from unhandled errors (see section
  2.6), so a returned error or an `ok = false` deserves its own case.
- **Make fuzzing deterministic.** Seed the generator yourself and print the seed on failure so any
  run reproduces. A fuzzer can only show the presence of bugs, and your assertions are the oracle
  that catches them.
- **Keep tests hermetic and fast.** Use a temp allocator or a fresh tracking allocator so a leak in
  the code under test fails the test too.
- Open each test with one line stating its goal and method, in the prose style of section 5.

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

Run development builds with every check on and release builds with the expensive ones off, chosen by
compiler flags rather than by editing code.

- **Development.** Build with `-debug -vet -strict-style` and keep assertions and the tracking
  allocator active. This is where the fuzzer and the assertions earn their keep.
- **Release.** Build with `-o:speed` (or `-o:aggressive`). Once you have measured a real cost, you may
  add `-disable-assert` to strip runtime `assert` calls and `-no-bounds-check` to remove slice and
  array bounds checks. Strip only what you have measured, and only after the code is proven.
- **Keep the compile time checks in every build.** `-vet` and `-strict-style` cost nothing at runtime
  and `#assert` is never stripped, so there is no reason to drop them for release.
- **Never put logic inside `assert`.** Because `assert` can be compiled out, an expression with a side
  effect inside it will vanish in release and change behavior. An assertion must only read state and
  check it, which is the contract that makes stripping safe.
- **Prefer surgical over global when removing bounds checks.** Annotate a proven hot loop with
  `#no_bounds_check` instead of disabling bounds checks for the whole program, so untrusted input
  paths keep their guard rails.

Ship the same assertions you developed with. Turning them off is a performance decision you earn by
measuring, not a default.

---

## 3. Odin Specific Idioms

Odin has opinions. Lean into them, because they encode much of the above for free.

### 3.1 Naming

Follow the official convention.

| Thing        | Case                          | Example                             |
| ------------ | ----------------------------- | ----------------------------------- |
| Types        | `Ada_Case`                    | `String_Builder`, `Read_Error`      |
| Enum values  | `Ada_Case`                    | `.Invalid_Argument`, `.End_Of_File` |
| Procedures   | `snake_case`                  | `reader_read_byte`                  |
| Variables    | `snake_case`                  | `byte_offset`, `read_count`         |
| Constants    | `SCREAMING_SNAKE_CASE`        | `DEFAULT_BUF_SIZE`, `MAX_DEPTH`     |
| Import names | `snake_case`, prefer one word | `import str "core:strings"`         |
| Acronyms     | keep caps together            | `JSON_Value`, not `Json_Value`      |

Be consistent. In particular, note the following.

- **Type names are always `Ada_Case`.** Don't use `SCREAMING_SNAKE` for a type (for example, an enum
  used as a "kind" or "mode"), because a SCREAMING name reads as a constant and misleads. Prefer
  `Open_Mode` over `MODE`.
- **Enum values are `Ada_Case`.** The sanctioned exception is a one to one port of a foreign API (for
  example, mirroring a C library's `SCREAMING` keycodes). Keep the foreign casing so the mapping is
  obvious, and comment that intent at the enum.

More naming discipline worth adopting.

- **The package is the namespace, so name procedures for their subject.** Odin has no methods, so the
  standard library prefixes procedures that operate on a type with that type's role: `reader_init`,
  `reader_destroy`, `builder_make`, `builder_reset`. Called as `bufio.reader_init`, this reads
  cleanly and groups related procedures together. Pair `init`/`destroy` and `make`/`delete` names so
  the lifetime is obvious. Don't name a bare `init` in a package that manages more than one type.
- **Don't over-abbreviate, but honor the established short names.** Spelling out `source`/`target`
  over `src`/`dst` is good when derived names must line up (`source_offset`, `target_offset`). But the
  standard library, and this style, freely use the conventional short names that every Odin reader
  knows: `len`, `cap`, `ptr`, `buf`, `n`, `i`/`j`, `r`/`w` for read/write cursors, `lo`/`hi`, and the
  loop and math indices. These are idiom, not abbreviation debt. Prefer a clear full word for a
  domain concept, and a short conventional name for a mechanical one.
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
error_message := [Error]string { ... }
month_days    := [Month]int    { ... }
```

- An `[Enum]T` table lets you index by the enum value itself, which is safer than a raw ordinal, and
  the compiler sizes it to the enum. It will not warn about a key you forget, which then reads as the
  zero value, so write every key explicitly. When you need a build time guarantee that every value is
  mapped, use an ordinal `[?]T` table and assert its length against `len(Enum)` (see section 2.1).
- Whenever you catch yourself copy pasting the same block of logic per case, drive it from a table
  instead.

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

  Shorter, one place to fix bugs, and shared rules are stated once instead of N times.

### 3.3 Distinct types and unions

- Use `distinct` to stop `index`, `count`, and byte offsets from being interchangeable when it
  matters. It's free type safety.
- When you `switch` on a union or enum, handle exactly the variants and let the compiler tell you when
  a variant is added. Don't paper over it with a catch all `else`.
- Prefer `Maybe(T)` over sentinel values when "absent" is a real state. `Maybe(u64)` beats "0 means none."
- **Reach for parametric polymorphism to reuse plain-data logic.** Odin's `$T`, type-specialized
  parameters like `$A/[]$T`, and `where` clauses are how the standard library writes one `linear_search`
  or `Small_Array` that works for every element type with zero runtime cost. Prefer a `where` clause
  (`where intrinsics.type_is_comparable(T)`) to state a constraint the compiler enforces, over a
  runtime check. Group related overloads with a `proc{...}` group (`builder_init :: proc{...}`) so
  callers see one name. This is the composable-small-procedures ideal expressed in Odin's own tools.

### 3.4 Use `defer` sparingly and deliberately

`defer` shines when a scope has _multiple_ exits and cleanup must run on all of them, and the standard
library uses it liberally for exactly that: pairing an acquire with its release, or an `or_return`
heavy proc with its teardown. It keeps cleanup next to the thing it cleans up, which is easier to
audit than a release buried at the far bottom.

The caution is real though: `defer` makes control flow nonlinear, so the reader can no longer follow
the code strictly top to bottom. So when a scope has a single, linear exit, prefer to just write the
cleanup at the end. Use `defer` when it buys you correctness across several exits, not as a reflex.

### 3.5 `context` and allocators

- The implicit `context.allocator` and `context.temp_allocator` are powerful and dangerous. Be
  explicit at boundaries. Pass the allocator you mean, especially for anything that outlives the
  current scope.
- In debug builds, wrap `context.allocator` in a tracking allocator to catch leaks and bad frees. It
  is your fuzzer for memory bugs, so keep it on for every debug run and watch the live allocation
  count.
- Per scope temp memory is a batching win (§4). Allocate freely into temp, then free it all at once.
  This is the control plane and data plane split applied to memory.
- **Library code takes an explicit `allocator` parameter; it does not assume the caller's temp
  allocator.** The standard library pattern is `proc(..., allocator := context.allocator, loc := #caller_location)`
  returning an `Allocator_Error`, so the caller owns the lifetime and chooses the allocator. The
  temp allocator is a caller-side convenience: use it at your own call sites, but do not bake it into
  a reusable procedure, whose caller may have a different lifetime in mind.

### 3.6 Use `when` for compile time branching

Use `when ODIN_OS == .Darwin` or `when ODIN_DEBUG` for platform and build mode differences. Compile
time branches cost nothing at runtime and keep the runtime path straight. Prefer them over a runtime
`if` for things that are decided at build time.

### 3.7 Struct and file ordering

Order a file top down by importance, because that's how it's read, and put `main` (or the primary
entry proc) first. Odin structs hold only fields, so this ordering applies to the file, not the
struct body. Put the primary type near the top, then its constructor `init`, then the procedures that
operate on it, from most to least important. Lift a complex helper type out to its own top level
declaration rather than burying it. When there's no natural order, sort alphabetically (big endian
names make this pleasant).

### 3.8 Options structs and named arguments

Odin's named arguments prevent positional mistakes. Two adjacent parameters of the same type that
could be swapped _must_ be passed by name at the call site, or wrapped in an options struct. Lean on
defaulted named params (`sorted := false`, `truncate := false`). Keep singleton dependencies (an
allocator, a state handle) positional and ordered from general to specific, and keep swappable values
named. If `nil` is a valid argument, name it so the meaning of the literal is clear at the call site.

### 3.9 Value construction

- Prefer `x := T{...}` over `x: T = {...}`, and prefer type inference (`s := load(...)`) except where
  an explicit type genuinely aids the reader.
- Use initializers, not field by field assignment, when constructing a value.
- For large structs, prefer initializing in place through an out pointer (`init :: proc(target: ^Big)`)
  rather than returning by value, to keep pointer stability and avoid intermediate copies. In place
  init is viral. If one field is initialized in place, initialize the whole container in place.
- Don't duplicate variables or take aliases to state, because that's how things get out of sync.
  Compute or check a value close to where it's used, and declare it at the smallest possible scope. A
  gap in space or time between check and use is where bugs hide.

### 3.10 Document nontrivial procedures with a doc comment

Odin has no reserved doc comment token, but the comment block immediately above a declaration, with
no blank line between, _is_ what the editor language server (OLS) shows on hover and completion.
Treat that block as the procedure's public contract. Both a run of `//` lines and a `/* ... */` block
work, and both appear in the standard library.

The standard library's convention for public API is a `/* ... */` block with labelled sections, and
you should follow it for anything you publish. The common headings are `Inputs:`, `Returns:`, and,
where it helps, `Example:` and `Output:`, plus a leading note like `*Allocates Using Provided
Allocator*` when the proc allocates. This is the format OLS renders richly and readers expect.

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

For a small internal helper, a single `//` line above the proc (as `core:bufio` does for
`reader_init`) is plenty. Reserve the full block for the package's public surface.

Not every proc needs one. A small proc with an obvious name and an obvious signature is its own
documentation, and a comment like `// returns the name` above `get_name` is noise that rots. Add a
doc comment when the proc is mid to large sized, is part of a package's public surface, or has a
contract the signature cannot express on its own.

Write the contract, not the mechanics. Cover only the parts a caller cannot see: ownership and
allocation (who frees the result, which allocator, whether it aliases internal or temp storage),
preconditions beyond the types, the meaning of a `nil`/empty/zero/`ok = false` result, side effects,
units and lifetime, and any surprising design choice. Keep the summary to one line, add only the
clauses that apply, and update the comment in the same commit that changes the behavior, because a
stale doc comment is worse than none. A comment that only restates the signature (`// Adds a and b`
over `add`) is noise; the `clone` block above is the shape to copy.

### 3.11 Visibility, and where it earns its place

By default every declaration in a package is visible to code that imports it. `@(private)` limits a
declaration to its package, and `@(private="file")` limits it to its file.

In ordinary application code you own every call site, so reaching for `@(private)` everywhere mostly
adds noise for little gain. Use it sparingly, to lock a specific invariant that must not be touched
from another file. In library code the calculus flips. You publish to consumers you do not control,
so hide the internals with `@(private)` and export only the surface you intend to support. That way
you can change how the library works without breaking the people who use it, which is the seam idea
from section 6.

---

## 4. Performance

> "The lack of back of the envelope performance sketches is the root of all evil."

- **Design for performance up front.** The 1000× wins live in the design, not the profiler. Sketch
  the four resources (network, disk, memory, CPU) and two axes (bandwidth, latency) on paper, aim
  within 90% of optimal by design, then measure.
- **Batch across boundaries.** Snapshot input once, act on the immutable snapshot, free scratch once
  at the boundary. Decide at the edges, act in bulk in the middle. Never react to an external event
  mid-work; run at your own pace so work per unit time stays bounded.
- **Keep the CPU on straight runs.** Long, predictable passes over contiguous data beat pointer
  chasing and branch-heavy lane changing.
- **Fix the slowest resource first, weighted by frequency.** Spend where frequency × latency is
  largest; a cache miss hit a million times can cost more than one fsync.
- **Make hot loops standalone and pure**, taking primitive args over a `^Struct`, so values stay in
  registers and redundant work is visible.
- **Only here does "small, simple, stupid" yield to speed**, and only with a comment, ideally a
  back-of-envelope number, justifying the trade.

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
  and expose narrowed procedures, so your code depends on the seam rather than the library and an
  implementation can be swapped without a rewrite. Quarantine foreign types and foreign naming behind
  that seam.
- **Standardize the toolbox.** Prefer one blessed way to build, run, and test over a drawer of ad hoc
  shell scripts. A small, shared toolbox is simpler to operate as the team and the range of tastes
  grow.
- **Explicitly pass options at call sites** instead of relying on library defaults, so a future
  default change can't silently alter behavior.

---

## 7. The Checklist (read before every change)

**Safety**

- [ ] Real invariants asserted where the type system and bounds checks don't already cover them,
      especially in index, pointer, and buffer math; positive _and_ negative space at boundaries.
- [ ] Compile time `#assert`s on enum and table lengths and struct size invariants.
- [ ] Every loop and buffer has a fixed, provable upper bound (or an asserted liveness reason), and
      any recursion is provably bounded.
- [ ] `int` for lengths/indices/counts, sized types for layouts and wire formats, with `index`,
      `count`, and `size` kept semantically distinct.
- [ ] Control flow is simple, with `if`s pushed up, no nested ternaries, no dead branches, and
      exhaustive enum switches.
- [ ] Pure and allocating procs marked `@(require_results)`; every error handled or loudly,
      deliberately ignored with a reason.

**Memory**

- [ ] No secret allocations, and every alloc has a known owner and a visible free.
- [ ] Per scope scratch uses a temp allocator, and nothing owned by temp escapes its scope unflagged.
- [ ] Caller owned state preferred over hidden global state.

**Composability & Simplicity**

- [ ] Small procs over plain data, and table driven over copy pasted `switch` logic.
- [ ] Prefer passing `^State` over reaching into hidden global state.
- [ ] About 70 lines per proc, about 100 columns per line, hourglass shape.

**Odin idiom**

- [ ] Ada_Case types, Ada_Case enum values, snake_case procs and vars, SCREAMING constants; procs
      named for their subject (`reader_init`), conventional short names honored.
- [ ] `defer` for cleanup across multiple exits; linear single-exit scopes just clean up at the end.
- [ ] Reuse via parametric polymorphism and `where` clauses; public API takes an explicit allocator.
- [ ] Public procs carry a `/* Inputs:/Returns: */` doc block that states the invisible contract.
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
- [ ] Commit message explains _why_, in the imperative.

> Keep trying things out, have fun, and remember that the best code is the code that's small enough to
> hold in your head all at once.

---

## Appendix A. Global & Persistent State (optional)

_Read this only if your program keeps mutable state alive across a boundary that can reset it, such as
a hot code reload, a plugin swap, or a save and restore. Most programs do not, and can skip it._

When you must have long-lived global state, make it disciplined.

1. **Concentrate persistent state in one owned graph**, reachable from a single root. Everything that
   must survive across a reload, a save, or a subsystem restart lives there.
2. **Package globals are caches of a pointer, not owners.** If a global points at state that must
   persist, repoint it after any event that can zero it, in an explicit `*_reload` step. Add such a
   global and you must add its repoint line, or you get silent corruption.
3. **Guard layout and version compatibility across boundaries.** When state crosses a reload or
   serialization boundary, verify the layout and version on both sides (for example, hash the layout
   of the old and new build and refuse an incompatible swap). This is a paired assertion across the
   boundary, so don't defeat it.
4. **Keep `init`, `shutdown`, and `reload` symmetric and nil guarded.** Every `*_shutdown` checks
   `if x == nil do return` and frees exactly what its `*_init` allocated. Watch the per-cycle leak
   count trend to zero.
5. **Keep the host and loader dumb and defensive.** Prefer reflection driven contract checks (reject a
   partially bound API rather than call a nil proc) so the loader doesn't need editing every time the
   contract grows.
