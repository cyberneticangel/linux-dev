# Dev environment: build, boot, iterate

The flake in this repo provides two shells:

| Shell | Where | What's in it |
|---|---|---|
| `nix develop` (default, via direnv) | Mac or Linux | git + `send-email`, b4, perl (checkpatch / get_maintainer), codespell, dtc, QEMU, `kboot` |
| `nix develop .#kernel` | **Linux only** | everything above, plus clang/lld/LLVM (`LLVM=1` is set), Rust + rust-src + clippy + rustfmt, bindgen, dtschema + yamllint, sparse, smatch, coccinelle, pahole, gdb, ccache, cscope, clangd, and the build deps (bison, flex, bc, openssl, elfutils, ncurses...) |

**Why Linux only:** kernel trees contain files whose names differ only in case, which breaks
on macOS' case-insensitive APFS. Upstream doesn't document macOS as a build host. Build inside
the aarch64 Linux VM, as with asahi-dev.

## 1. First-time setup (in the Linux VM)

```sh
cd linux-dev                    # this repo, shared into the VM or cloned there
nix develop .#kernel            # or: echo 'use flake .#kernel' > .envrc.local + direnv
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux
cd linux
```

`linux/` is gitignored. Mainline is the base, but **don't develop against it**. Base each
series on the tree from the subsystem's `T:` line in `MAINTAINERS`. Add those trees as remotes:

```sh
git remote add next  https://git.kernel.org/pub/scm/linux/kernel/git/next/linux-next.git
git remote add soc   https://git.kernel.org/pub/scm/linux/kernel/git/soc/soc.git
git remote add asahi https://github.com/AsahiLinux/linux.git        # downstream, branch `asahi`
git remote add rust  https://github.com/Rust-for-Linux/linux.git    # branch rust-next
git fetch --all
```

Run the `git config` bits from [submitting-patches.md](submitting-patches.md#git-config) once.

## 2. Configure and build

```sh
make defconfig                       # arm64 defconfig already includes QEMU virt support
./scripts/config -e DEBUG_INFO_DWARF5 -e GDB_SCRIPTS    # optional, for gdb
make olddefconfig
make -j"$(nproc)"                    # LLVM=1 comes from the shell
```

- **Out-of-tree build dir:** `make O=../build/arm64 ...`, or `export KBUILD_OUTPUT=...`
  (`kboot` honours it too). The submit checklist says your change must also build with `O=`.
- **Config fragments:** `make defconfig debug.config` merges `kernel/configs/debug.config`.
  Others include `rust.config`, `kvm_guest.config`, `hardening.config` and
  `arch/arm64/configs/virt.config`.
- **Cross-compile** (e.g. on an x86_64 box): `make ARCH=arm64 defconfig all`. With `LLVM=1`
  you don't need `CROSS_COMPILE` (`Documentation/kbuild/llvm.rst`).
- **Single object / directory:** `make drivers/soc/apple/` or `make drivers/soc/apple/rtkit.o`.
- **DTBs only:** `make dtbs`, or a single file: `make apple/t8103-j274.dtb`.
- **ccache:** `KBUILD_BUILD_TIMESTAMP='' make CC="ccache clang"`. Without the fixed timestamp,
  every build misses the cache.
- **Editor / clangd:** run `make compile_commands.json` (or
  `./scripts/clang-tools/gen_compile_commands.py`) after a build. For Rust, run
  `make rust-analyzer` to generate `rust-project.json`.

## 3. Rust

```sh
make rustavailable                   # explains exactly what's missing, if anything
make menuconfig                      # General setup → Rust support (CONFIG_RUST)
make LLVM=1 CLIPPY=1                 # extra lints (don't use for production builds)
make rustfmtcheck                    # or `make rustfmt` to fix
make rustdoc                         # local docs: Documentation/output/rust/rustdoc/kernel/
```

Minimums (Documentation/process/changes.rst @ 7.3): Rust 1.85.0, bindgen 0.71.1, Clang 17.
The flake pins Rust stable latest, bindgen 0.72 and clang 21. Online API docs:
https://rust.docs.kernel.org (`/next/` for linux-next).

## 4. Boot it: `kboot`

`kboot` boots the kernel you just built in QEMU, with a busybox initramfs that drops you into a
shell. Exiting the shell powers the VM off.

```sh
kboot                                 # arch/<ARCH>/boot/Image (+ KBUILD_OUTPUT), console on serial
KBOOT_APPEND="nokaslr loglevel=8" kboot
KBOOT_SMP=1 KBOOT_MEM=512M kboot
kboot -s -S                           # extra args go to QEMU: here, wait for gdb on :1234
```

- Acceleration is picked automatically: KVM if `/dev/kvm` is writable, hvf on a Mac host,
  TCG otherwise. In a VM without nested virtualisation it falls back to TCG, which is slower
  but fine for a busybox boot.
- Quit QEMU with `Ctrl-a x`.
- **On the Mac (hvf, fastest):** copy `arch/arm64/boot/Image` and the initramfs out of the VM
  (`echo $KBOOT_INITRD` in the kernel shell), then
  `KBOOT_IMAGE=Image KBOOT_INITRD=kboot-initramfs.cpio.gz ARCH=arm64 kboot`.
- This is for generic and core code. Apple-SoC drivers need real hardware via m1n1 (see
  `../asahi-dev/notes/`).

## 5. Debugging with gdb

```sh
# terminal 1
KBOOT_APPEND=nokaslr kboot -s -S
# terminal 2 (CONFIG_GDB_SCRIPTS=y, CONFIG_DEBUG_INFO=y)
make scripts_gdb
gdb vmlinux -ex 'target remote :1234'
(gdb) lx-symbols        # load module symbols
(gdb) lx-dmesg / lx-ps / lx-lsmod
```

Docs: `Documentation/process/debugging/gdb-kernel-debugging.rst`.

## 6. Daily loop

```sh
git switch -c topic/<name> <maintainer-tree>/<branch>
# edit
make -j"$(nproc)" && kboot                      # or test on hardware
./scripts/checkpatch.pl --strict -g origin..    # every commit on the branch
make C=1 W=1 drivers/foo/                       # sparse + extra warnings on what you touched
b4 prep --check                                  # see submitting-patches.md
```

## 7. Updating the environment

`nix flake update` updates nixpkgs and rust-overlay. `flake.lock` started as a copy of
asahi-dev's lock, so both shells resolve the same nixpkgs until one of them is updated.
