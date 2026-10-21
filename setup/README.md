# Setup

Get from zero to "built a kernel and booted it". Pick your host:

| Host | Guide |
|---|---|
| Linux, x86_64 or aarch64 (incl. NixOS) | [`linux/`](linux/README.md): build natively, no VM |
| macOS on Apple Silicon | [`macos/`](macos/README.md): build inside a Lima VM ([`kernel.yaml`](macos/kernel.yaml)) |

More detail on the build-and-boot loop lives in [`../notes/environment.md`](../notes/environment.md).

**Rule zero: the kernel tree must be on a case-sensitive Linux filesystem.** Never put it on
macOS or under a folder shared from macOS.

## Which host for what

| Host | Builds | `kboot` |
|---|---|---|
| aarch64 Linux (Mac VM, Ampere, Pi 5, Asahi on M1/M2) | arm64 natively | KVM |
| x86_64 Linux, native kernels | x86_64 | KVM |
| x86_64 Linux, Apple work | `make ARCH=arm64 ...` (LLVM=1, no extra toolchain) | **not yet working:** the initramfs busybox is built for the host, so `/init` fails in an arm64 guest (TODO: build the initramfs per target arch) |

## What to expect

- **First time in the kernel shell:** Nix downloads the toolchain (LLVM, Rust, QEMU, ...), a
  few GB.
- **`defconfig` build on 8 cores:** roughly 5–10 minutes. Incremental rebuilds are much faster.
- **`kboot`:** drops you into a busybox shell. Exit the shell, or press `Ctrl-a x`, to quit.
  Try `dmesg | head` and `cat /proc/version`.
- **If something fails** (Nix shell, build, `/dev/kvm`, `kboot`): it hasn't been tested end to
  end yet, so capture the error and fix the flake.

## Next

1. Get comfortable with the build-and-boot loop: add a `pr_info()`, write a hello module, turn it
   into a platform driver bound by a DT compatible, and try KASAN, lockdep and gdb (`kboot -s -S`).
2. Read the Apple code: `arch/arm64/boot/dts/apple/t8103.dtsi`, `drivers/irqchip/irq-apple-aic.c`,
   `drivers/soc/apple/`, then compare mainline with linux-asahi's T8140 / T8132 support.
3. Follow asahi@lists.linux.dev on lore, test series with `b4 shazam`, and join #asahi-dev (OFTC).
4. First patches: a `dtbs_check W=1` warning fix as a warm-up, then the M5 (T8142) series that
   gets it booting to a serial console: bindings → `t8142.dtsi` + board DTS.

See [`../notes/README.md`](../notes/README.md) for process, style, DT and testing notes.
