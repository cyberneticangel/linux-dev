# linux-dev

Personal environment and notes for upstream Linux kernel work. It's the sibling of
`../asahi-dev` (m1n1 / Asahi bring-up).

```
flake.nix    dev shells: default (Mac + Linux: b4, send-email, QEMU, kboot)
             and .#kernel (Linux only: LLVM, Rust, bindgen, dtschema, sparse, smatch, cocci, gdb)
.envrc       direnv: `use flake`
setup/       host setup, start here: linux/ (native) or macos/ (Lima VM, kernel.yaml)
notes/       kernel process / style / DT / testing notes; start at notes/README.md
scripts/kdev configure + build (out of tree, build/<arch>) + boot in QEMU; kdev -h
linux/       kernel checkout on a native Linux box (gitignored; in the Lima VM use ~/src/linux)
```

Quick start:

```sh
# on the Mac
limactl create --name=kernel setup/macos/kernel.yaml && limactl start kernel && limactl shell kernel
# in the VM
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git ~/src/linux
cd ~/src/linux && nix develop /Users/dylan/dev/linux-dev#kernel
make defconfig && make -j"$(nproc)" && kboot
```

On native Linux, `scripts/kdev` does all of that (clone into `linux/` first).

Full setup: [setup/linux](setup/linux/README.md) or [setup/macos](setup/macos/README.md). Details: [notes/environment.md](notes/environment.md).
