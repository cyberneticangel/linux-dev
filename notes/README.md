# Linux kernel notes

Working notes for upstream kernel work, mostly with Apple Silicon (Asahi / M5 bring-up), arm64,
devicetree and Rust in mind. They're distilled from `Documentation/` in torvalds/linux.

**Source snapshot:** torvalds/linux @ `a804c5742bff` (2026-10-20, v7.3 plus 7.4 merge-window
pulls). Paths like `Documentation/process/...` are relative to a kernel tree (`../linux/`
once cloned). **The upstream docs win** over these notes, so re-check them when rules matter.

| File | What's in it |
|---|---|
| [getting-started.md](getting-started.md) | Beginner roadmap from a security background: build loop, security code paths, syzbot, first patch |
| [environment.md](environment.md) | Using this repo's flake: build, Rust, `kboot` in QEMU, gdb, daily loop |
| [development-process.md](development-process.md) | Release cycle, merge window timing, which tree takes what, stable, regressions |
| [submitting-patches.md](submitting-patches.md) | Commit messages, tags, **DCO and AI-tool rules**, checklist, b4 / send-email, review etiquette |
| [coding-style.md](coding-style.md) | C style essentials, the deprecated-API table, Kconfig, Rust guidelines |
| [devicetree-and-soc.md](devicetree-and-soc.md) | Bindings vs DTS, series layout, binding design rules, DTS style, `dtbs_check`, arm64 boot protocol, Apple pointers |
| [testing-and-debugging.md](testing-and-debugging.md) | KUnit vs kselftest, debug config set, sanitizers, sparse/smatch/cocci, debugging techniques |

## Five rules worth memorising

1. **Base your work on the maintainer's tree** (`T:` in MAINTAINERS), not mainline, and send
   with `--base`.
2. **One logical change per patch, and every patch builds.** Bindings → driver → DTS.
3. **Explain *why* in the commit message**, in the imperative, wrapped at 75 columns, with
   `Fixes:` / `Closes:` where they apply.
4. **Only humans sign off.** Disclose meaningful AI or tool involvement
   (`generated-content.rst`, `coding-assistants.rst`).
5. **checkpatch, sparse, W=1 and dtbs_check are clean before sending.** Wait a week before
   pinging, and answer every comment.

## Upstream docs worth reading in full

- `Documentation/process/submitting-patches.rst` (all of it, once)
- `Documentation/process/coding-style.rst`
- `Documentation/devicetree/bindings/writing-bindings.rst` + `submitting-patches.rst`
- `Documentation/process/maintainer-soc.rst`
- `Documentation/rust/coding-guidelines.rst` + `general-information.rst`
- `Documentation/arch/arm64/booting.rst`
- `Documentation/process/development-process.rst` (chapters 1–8: the long-form guide)
- Rendered: https://docs.kernel.org · Rust API: https://rust.docs.kernel.org · Archives: https://lore.kernel.org
