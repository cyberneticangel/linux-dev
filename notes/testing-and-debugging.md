# Testing, static analysis, debugging

Sources: `Documentation/dev-tools/` (`testing-overview.rst`, `kunit/`, `kselftest.rst`,
`kasan.rst`, `kcsan.rst`, `kfence.rst`, `ubsan.rst`, `kmemleak.rst`, `sparse.rst`,
`coccinelle.rst`, `checkpatch.rst`), `Documentation/process/debugging/`, `submit-checklist.rst`,
`Documentation/rust/testing.rst`.

## Which test framework?

| | KUnit | kselftest |
|---|---|---|
| Runs | inside the kernel (white box) | userspace programs and scripts |
| Good for | single functions, error paths, parsers, helpers | whole features via syscalls, sysfs, devices |
| Speed | seconds (UML or QEMU) | needs a booted system |
| Required for | n/a | new syscalls must ship with one |

### KUnit

```sh
./tools/testing/kunit/kunit.py run                                  # UML, default config
./tools/testing/kunit/kunit.py run --arch arm64 --make_options LLVM=1   # QEMU (qemu_configs/arm64.py)
./tools/testing/kunit/kunit.py run --kunitconfig drivers/foo            # a dir with .kunitconfig
./tools/testing/kunit/kunit.py run --kconfig_add CONFIG_RUST=y 'rust_doctests_kernel*'
```

- Tests live next to the code (`foo_test.c` or `tests/`) and get a `.kunitconfig`. See
  `kunit/style.rst` for naming (`<subsystem>_<thing>_test`).
- Results come out as KTAP (`ktap.rst`). You can also build tests in and read them from the boot log.
- Rust: doc examples (`/// ```...```) become KUnit tests via `CONFIG_RUST_KERNEL_DOCTESTS`.
  `#[kunit_tests(name)]` modules work too. `make rusttest` runs host-side `#[test]`s for the
  few crates that support it.

### kselftest

```sh
make TARGETS="timers size" kselftest            # build + run on the running kernel
make -C tools/testing/selftests TARGETS=ptrace run_tests
make O=/tmp/ks kselftest-install                # then copy to the target and run run_kselftest.sh
```

To run them under `kboot`, install into a directory and add it to the initramfs, or boot a
fuller rootfs.

## Debug Kconfig set (submit-checklist: test with all of these on at once)

```
CONFIG_PREEMPT  CONFIG_DEBUG_PREEMPT  CONFIG_SLUB_DEBUG  CONFIG_DEBUG_PAGEALLOC
CONFIG_DEBUG_MUTEXES  CONFIG_DEBUG_SPINLOCK  CONFIG_DEBUG_ATOMIC_SLEEP
CONFIG_PROVE_LOCKING (lockdep)  CONFIG_PROVE_RCU  CONFIG_DEBUG_OBJECTS_RCU_HEAD
```

`make debug.config` (from `kernel/configs/debug.config`) gets you most of the way. Also
test with and without `SMP`, and with fault injection for slab and page allocation
(`Documentation/fault-injection/`).

## Dynamic analysis

| Tool | Finds | Cost | Enable |
|---|---|---|---|
| KASAN | out-of-bounds, use-after-free | high (generic) / low (HW tags, MTE) | `CONFIG_KASAN` |
| KFENCE | the same, sampled; fine for production | ~0 | `CONFIG_KFENCE` |
| UBSAN | undefined behaviour (shifts, bounds, overflow) | low | `CONFIG_UBSAN` (+ `_BOUNDS`) |
| KCSAN | data races | high | `CONFIG_KCSAN` |
| KMSAN | uninitialised reads (x86_64, clang) | very high | `CONFIG_KMSAN` |
| kmemleak | leaks | medium | `CONFIG_DEBUG_KMEMLEAK`; `echo scan > /sys/kernel/debug/kmemleak` |
| lockdep | lock ordering, IRQ-safety | medium | `CONFIG_PROVE_LOCKING` |
| KCOV | coverage for fuzzers (syzkaller) | n/a | `CONFIG_KCOV` |

## Static analysis

```sh
./scripts/checkpatch.pl --strict -g <base>..        # style; also run on .patch files
./scripts/checkpatch.pl --strict -f drivers/foo.c   # whole file (only for new files you own)
make C=1 drivers/foo/          # sparse on files being rebuilt (C=2: all files)
make CHECK="smatch -p=kernel" C=1 drivers/foo/      # smatch
make coccicheck MODE=report M=drivers/foo/          # Coccinelle semantic patches
make W=1 drivers/foo/          # extra compiler warnings (W=12, W=123 are noisier)
make checkstack                # big stack frames
make CLIPPY=1                  # Rust lints
make dt_binding_check dtbs_check   # DT (see devicetree-and-soc.md)
make htmldocs                  # kernel-doc / Documentation warnings (needs sphinx; not in the flake)
```

Sparse catches `__iomem`/`__user`/endianness (`__le32`) mix-ups and lock-context
annotations. Use it on anything that does MMIO.

## Debugging techniques

- **printk / dynamic debug:** `pr_debug`/`dev_dbg` compile to nothing unless
  `CONFIG_DYNAMIC_DEBUG` is set. Then:
  `echo 'file drivers/soc/apple/* +p' > /sys/kernel/debug/dynamic_debug/control`, or at
  boot: `dyndbg="module foo +p"`.
- **Early boot output:** `earlycon` (arm64 with a DT `stdout-path`), `keep_bootcon`,
  `loglevel=8`, `initcall_debug`, `ignore_loglevel`.
- **Decoding oopses:** `./scripts/decode_stacktrace.sh vmlinux < oops.txt`, or
  `./scripts/faddr2line vmlinux func+0x1c/0x80`.
- **ftrace:** `/sys/kernel/tracing` (function_graph, events), `trace-cmd`, `trace_printk()`
  for temporary debugging only.
- **gdb + QEMU:** `kboot -s -S` with `nokaslr`, then `gdb vmlinux` plus `lx-*` helpers
  (see [environment.md](environment.md#5-debugging-with-gdb)). kgdb works over serial on
  real hardware (`kgdb.rst`).
- **Bisecting:** `git bisect start <bad> <good>`, then `git bisect run` with a script that
  builds and boots via `kboot`. Requires bisectable series, which is why every patch must build.
- **Apple hardware:** the m1n1 hypervisor traces MMIO and boots Linux under it. See
  `../asahi-dev/notes/m1n1-starter-guide.md`.
