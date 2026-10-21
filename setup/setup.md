# Setup

Get from zero to "built a kernel and booted it" on either a Mac (via a Linux VM) or native Linux.
More detail lives in [`../notes/environment.md`](../notes/environment.md).

**Rule zero: the kernel tree must be on a case-sensitive Linux filesystem.** Never put it on
macOS or under a folder shared from macOS.

## A. Mac (Apple Silicon) → Lima VM

The VM is defined in [`../lima/kernel.yaml`](../lima/kernel.yaml): aarch64 Debian 13 on Apple's
Virtualization framework, 8 CPUs, 8 GiB RAM, a 100 GiB sparse disk and **nested virtualization**
(needs M3 or later, so `/dev/kvm` exists and `kboot` uses KVM). `~/dev` is shared with
read/write access. First boot installs Nix (Determinate) and direnv.

```sh
# on the Mac (Lima is installed via Homebrew)
cd ~/dev/linux-dev
limactl create --name=kernel lima/kernel.yaml
limactl start kernel            # first time: downloads Debian, installs Nix (a few minutes)
limactl shell kernel
```

Check it inside the VM:

```sh
ls -l /dev/kvm                  # exists = nested virtualization works
nix --version
ls /Users/dylan/dev/linux-dev   # Mac folder is shared
nproc; free -h                  # 8 CPUs, ~8 GB
```

Build (inside the VM):

```sh
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git ~/src/linux
cd ~/src/linux
echo 'use flake /Users/dylan/dev/linux-dev#kernel' > .envrc && direnv allow
echo .envrc >> .git/info/exclude
make defconfig && make -j"$(nproc)" && kboot
```

Gotchas:
- The shared folder keeps its **Mac path** in the guest (`/Users/dylan/dev`). The guest's `~` is
  `/home/dylan.linux`, so `~/dev` doesn't exist there.
- The kernel tree goes in `~/src/linux` (VM disk), **not** under `/Users/dylan/dev`.
- Lima logs live in `~/.lima/kernel/` (`serial*.log`, `ha.stderr.log`).
- Too much RAM pressure on macOS? Lower `memory` in `~/.lima/kernel/lima.yaml`, then
  `limactl stop kernel && limactl start kernel`.
- Native Linux on this Mac (M5) isn't possible yet: Asahi doesn't support the M5. That's the work.

## B. Native Linux (aarch64 or x86_64)

```sh
# Nix + direnv
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
sudo apt install direnv                       # or dnf / pacman
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc

# KVM access for fast kboot (log out and back in afterwards)
sudo usermod -aG kvm "$USER"

# environment + kernel tree (linux/ is gitignored inside the repo)
git clone https://github.com/cyberneticangel/linux-dev.git ~/dev/linux-dev
cd ~/dev/linux-dev && direnv allow
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux
cd linux
echo 'use flake ..#kernel' > .envrc && direnv allow
echo .envrc >> .git/info/exclude
make defconfig && make -j"$(nproc)" && kboot
```

**NixOS:** skip the Nix install. Set `programs.direnv.enable = true;` and enable flakes
(`nix.settings.experimental-features = [ "nix-command" "flakes" ];`). The rest is the same.

Which host for what:

| Host | Builds | `kboot` |
|---|---|---|
| aarch64 Linux (Mac VM, Ampere, Pi 5, Asahi on M1/M2) | arm64 natively | KVM |
| x86_64 Linux, native kernels | x86_64 | KVM |
| x86_64 Linux, Apple work | `make ARCH=arm64 ...` (LLVM=1, no extra toolchain) | **not yet working:** the initramfs busybox is built for the host, so `/init` fails in an arm64 guest (TODO: build the initramfs per target arch) |

## C. What to expect

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
