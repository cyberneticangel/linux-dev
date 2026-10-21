# Setup: native Linux (x86_64 or aarch64)

No VM needed: build on the host and boot test kernels in QEMU with `kboot` (KVM-accelerated).
Any distro works; the toolchain comes from the flake, not the distro.

## 1. Nix, direnv and KVM

```sh
curl -fsSL https://install.determinate.systems/nix | sh -s -- install
sudo apt install direnv                       # or dnf / pacman
sudo usermod -aG kvm "$USER"                  # fast kboot; log out and back in afterwards
```

Hook direnv into your shell:

```sh
echo 'eval "$(direnv hook bash)"' >> ~/.bashrc                        # bash
echo 'direnv hook fish | source' >> ~/.config/fish/config.fish       # fish
```

Check: `ls -l /dev/kvm` should be writable by you (group `kvm`, or mode `rw-rw-rw-` on some
distros).

**NixOS:** skip the Nix install. Set `programs.direnv.enable = true;` and enable flakes
(`nix.settings.experimental-features = [ "nix-command" "flakes" ];`). The rest is the same.

## 2. Environment and kernel tree

`linux/` and `build/` at the repo root are gitignored, so the kernel tree lives inside the repo:

```sh
git clone https://github.com/cyberneticangel/linux-dev.git ~/dev/linux-dev
cd ~/dev/linux-dev && direnv allow
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux
cd linux
echo 'use flake ..#kernel' > .envrc && direnv allow
echo .envrc >> .git/info/exclude              # keep it out of kernel commits
```

## 3. Build and boot

```sh
scripts/kdev            # from the repo root: configure, build into build/<arch>, boot
scripts/kdev -h         # options: -a arm64, -g for gdb, -r to reconfigure, ...
```

Or by hand, inside `linux/`: `make defconfig && make -j"$(nproc)" && kboot`.

Continue with [`../../notes/environment.md`](../../notes/environment.md) (remotes, config,
Rust, gdb).
