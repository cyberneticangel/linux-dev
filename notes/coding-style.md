# Coding style: C, Rust, Kconfig

Sources: `Documentation/process/coding-style.rst`, `deprecated.rst`, `submit-checklist.rst`,
`Documentation/rust/coding-guidelines.rst`, `Documentation/rust/general-information.rst`.
Tooling: `scripts/checkpatch.pl`, `.clang-format` (helps, but isn't authoritative), `rustfmt`.

**Rule zero:** match the file you're editing. Subsystems may be stricter (see
`Documentation/process/maintainer-handbooks.rst`, e.g. netdev and tip).

## C essentials

- **Tabs, 8 wide.** No spaces for indentation. If you're past 3 levels deep, refactor.
- **80 columns preferred.** You may exceed it when breaking the line hurts readability
  (checkpatch warns at 100). **Never split user-visible strings** (people grep for them).
- **Braces:** K&R. The opening brace goes on the same line, *except for functions* (own line).
  Skip braces for single statements, unless another branch of the same `if` has them.
  `} else {` and `} while (x);` stay on one line.
- **Spaces:** after `if switch case for do while`; not after `sizeof typeof alignof __attribute__`.
  `*` binds to the name: `char *p`. No trailing whitespace.
- **Naming:** lowercase with underscores, descriptive for globals and short for locals (`i`,
  `tmp`). No Hungarian notation.
- **Typedefs:** generally no. Don't typedef structs or pointers. The exceptions are opaque
  types, plain integer types like `u8`/`u32`/`__be32`, and sparse-checked types.
- **Functions:** short, doing one thing; ≤5–10 locals. In prototypes, include parameter names.
  `EXPORT_SYMBOL*` goes right after the function's closing brace.
- **Error paths:** a centralised `goto` exit with labels named for what they do
  (`out_free_buffer:`), unwinding in reverse order. Cleanup helpers (`__free()`, `guard()`,
  `scoped_guard()` from `<linux/cleanup.h>`) are increasingly preferred in new code. Follow the
  subsystem.
- **Return values:** functions that perform an action return `0` or `-Exxx`. Predicates
  return `bool`. Pointer-returning functions use `NULL` or `ERR_PTR()`.
- **Comments:** explain *what* and *why*, not *how*. Multi-line style is `/*\n * ...\n */`.
  Document exported APIs with kernel-doc (`/** ... */`).
- **Macros:** enums over `#define` for related constants. Multi-statement macros use
  `do { } while (0)`. Parenthesise arguments. No hidden control flow. Prefer `static inline`.
- **`inline`:** don't use it for anything longer than about 3 lines. Let the compiler decide.
- **`#ifdef`:** keep them out of `.c` bodies. Put stubs in headers, or use
  `if (IS_ENABLED(CONFIG_FOO))` so both branches get compile-checked.
- **Printing:** `dev_err/warn/info/dbg(dev, ...)` when you have a device, `pr_*()` otherwise,
  with a `pr_fmt` prefix. Don't print on `-ENOMEM` (the allocator already warns). In probe, use
  `return dev_err_probe(dev, ret, "...")`.
- **Allocation:** new code uses the type-aware `kmalloc_obj()` family (`gfp` is optional and
  defaults to `GFP_KERNEL`): `p = kzalloc_obj(*p);`, `kmalloc_objs(*p, n)`,
  `kmalloc_flex(*p, member, n)`. The older form is `kmalloc(sizeof(*p), gfp)`, sized from the
  variable rather than the type. Don't cast the `void *` result.
- **Don't crash the kernel:** `WARN_ON_ONCE()` plus graceful handling, not `BUG()`.
- **Inline asm:** only when C can't do it. Use `volatile` only with a reason.
  `volatile` for shared data is wrong (`volatile-considered-harmful.rst`).
- **Barriers:** every `smp_*mb()`, `rmb()` or `wmb()` needs a comment saying what it pairs with.
- **Includes:** include what you use, and don't rely on transitive headers.
- SPDX tag on the first line: `// SPDX-License-Identifier: GPL-2.0-only` in `.c`,
  `/* ... */` in `.h` (`license-rules.rst`).

## Deprecated: don't add new uses (`deprecated.rst`)

| Don't | Use |
|---|---|
| `BUG()` / `BUG_ON()` | `WARN_ON_ONCE()` plus recovery |
| open-coded `a * b` in allocator args | `kmalloc_array`, `kcalloc`, `struct_size()`, `array_size()`, `size_mul()` |
| `simple_strto*()` | `kstrto*()` |
| `strcpy`, `strncpy`, `strlcpy` | `strscpy()` / `strscpy_pad()`; `strtomem()` / `strtomem_pad()` for non-NUL-terminated fixed-width fields; `memcpy_and_pad()` |
| new `%p` (it's hashed) | `%pS` for text addresses; otherwise drop it. `%px` only with a justification Linus would accept; boot with `no_hash_pointers` while debugging |
| VLAs | fixed size or allocate |
| implicit `switch` fall-through | the `fallthrough;` pseudo-keyword |
| `[0]` / `[1]` trailing arrays | flexible arrays `[]` plus `__counted_by()`; `struct_size()` |
| `kmalloc(sizeof(*p), …)`, `kcalloc(n, sizeof(*p), …)` | `kmalloc_obj(*p)`, `kzalloc_objs(*p, n)`, `kmalloc_flex(*p, member, n)` |
| `__deprecated` attribute | remove the API or list it in deprecated.rst |

## Kconfig

- Tab indent for the body, and tab plus 2 spaces for the `help` text.
- Every option gets help text. Default to off unless it meets the documented exceptions.
- `select` only for symbols with no dependencies of their own. Otherwise use `depends on`.
- Guard platform drivers with `depends on ARCH_APPLE || COMPILE_TEST` so that build bots
  compile-test them everywhere.

## Rust (`Documentation/rust/coding-guidelines.rst`)

- Format with `rustfmt` (`make rustfmt` / `make rustfmtcheck`), using the default settings.
  Lint with `make CLIPPY=1`.
- **Imports go vertical:** one item per line, braces as soon as there's more than one item,
  and a trailing `//` on the last item to stop rustfmt from collapsing them:
  ```rust
  use kernel::{
      device,
      platform,
      prelude::*, //
  };
  ```
- **Every `unsafe` block is preceded by `// SAFETY: <why this is sound>`.** Every `unsafe fn`
  or `unsafe trait` documents a `# Safety` section with the caller's contract. These are not
  the same thing.
- Documentation uses rustdoc (`///`, Markdown). Plain `//` comments aren't documentation.
  Doc examples turn into KUnit tests (`CONFIG_RUST_KERNEL_DOCTESTS`), so keep them compiling.
- Use the kernel's `Result`/`Error` and `?`. Don't panic in kernel paths. Allocation is
  fallible (`KBox::new(x, GFP_KERNEL)?`, `KVec`).
- **Layering:** drivers use only safe abstractions from `rust/kernel/`. **Leaf drivers must not
  call `bindings::` directly.** Missing a C API? Add the header to
  `rust/bindings/bindings_helper.h` and write an abstraction in `rust/kernel/`. For inline
  functions or macros, add a helper in `rust/helpers/`. These go to the subsystem's
  maintainers plus rust-for-linux@.
- Conditional compilation: `#[cfg(CONFIG_X)]`, `#[cfg(CONFIG_X = "y")]`. For version checks,
  add a Kconfig symbol (`def_bool RUSTC_VERSION >= 108800`).
- Abstractions you'll likely touch for Apple drivers: `platform`, `of`, `device`, `devres`,
  `io` (MMIO), `irq`, `clk`, `regulator`, `dma`, `drm`, `iommu`, `soc`, `firmware`, `sync`
  (`Mutex`, `SpinLock`, `Arc`), and `pin-init` (`try_pin_init!`).
