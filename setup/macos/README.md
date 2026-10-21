# Setup: macOS (Apple Silicon) → Lima VM

macOS can't build the kernel: kernel trees contain files whose names differ only in case, which
breaks on APFS (case-insensitive), and upstream doesn't support macOS as a build host. So you
build inside an aarch64 Linux VM and edit from either side.

The VM is defined in [`kernel.yaml`](kernel.yaml): aarch64 Debian 13 on Apple's Virtualization
framework, 8 CPUs, 8 GiB RAM, a 100 GiB sparse disk and **nested virtualization** (needs M3 or
later, so `/dev/kvm` exists and `kboot` uses KVM). `~/dev` is shared over virtiofs with
read/write access. First boot installs Nix (Determinate) and direnv.

## 1. Create the VM

```sh
# on the Mac (Lima is installed via Homebrew)
cd ~/dev/linux-dev
limactl create --name=kernel setup/macos/kernel.yaml
limactl start kernel            # first time: downloads Debian, installs Nix (a few minutes)
limactl shell kernel            # or: ssh -F ~/.lima/kernel/ssh.config lima-kernel
```

Check it inside the VM:

```sh
ls -l /dev/kvm                  # exists = nested virtualization works
nix --version
ls /Users/dylan/dev/linux-dev   # Mac folder is shared
nproc; free -h                  # 8 CPUs, ~8 GB
```

## 2. Kernel tree and build (inside the VM)

```sh
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git ~/src/linux
cd ~/src/linux
echo 'use flake /Users/dylan/dev/linux-dev#kernel' > .envrc && direnv allow
echo .envrc >> .git/info/exclude          # keep it out of kernel commits
make defconfig && make -j"$(nproc)" && kboot
```

`cd ~/src/linux` now loads the kernel shell automatically. Continue with
[`../../notes/environment.md`](../../notes/environment.md) (remotes, config, Rust, gdb).

## Gotchas

- **Never put a kernel tree under the `~/dev` mount.** It's the Mac's case-insensitive
  filesystem. Kernel trees go on the VM disk: `~/src/linux`.
- The shared folder keeps its **Mac path** in the guest (`/Users/dylan/dev`). The guest's `~` is
  `/home/dylan.linux`, so `~/dev` doesn't exist there. The flake is at
  `/Users/dylan/dev/linux-dev`, and `nix develop /Users/dylan/dev/linux-dev#kernel` works from
  any directory.
- Stop with `limactl stop kernel`. Too much RAM pressure on macOS? Lower `memory` in
  `~/.lima/kernel/lima.yaml`, then `limactl stop kernel && limactl start kernel`.
- Lima logs live in `~/.lima/kernel/` (`serial*.log`, `ha.stderr.log`).
- Native Linux on this Mac (M5) isn't possible yet: Asahi doesn't support the M5. That's the work.

## Booting on the Mac with hvf (optional, fastest)

`kboot` inside the VM uses nested KVM. For the fastest boots, run QEMU on the Mac itself (the
default `nix develop` shell works on macOS): copy `arch/arm64/boot/Image` and the initramfs out
of the VM (`echo $KBOOT_INITRD` in the kernel shell), then

```sh
KBOOT_IMAGE=Image KBOOT_INITRD=kboot-initramfs.cpio.gz ARCH=arm64 kboot
```
