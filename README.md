# linux-dev

Personal environment and notes for upstream Linux kernel work. It's the sibling of
`../asahi-dev` (m1n1 / Asahi bring-up).

```
flake.nix    dev shells: default (Mac + Linux: b4, send-email, QEMU, kboot)
             and .#kernel (Linux only: LLVM, Rust, bindgen, dtschema, sparse, smatch, cocci, gdb)
.envrc       direnv: `use flake`
setup/       setup.md: VM or native Linux setup, start here
notes/       kernel process / style / DT / testing notes; start at notes/README.md
lima/        kernel.yaml: the aarch64 Linux VM (Lima, nested KVM)
scripts/kdev configure + build (out of tree, build/<arch>) + boot in QEMU; kdev -h
linux/       kernel checkout on a native Linux box (gitignored; in the Lima VM use ~/src/linux)
```

Quick start:

```sh
# on the Mac
limactl create --name=kernel lima/kernel.yaml && limactl start kernel && limactl shell kernel
# in the VM
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git ~/src/linux
cd ~/src/linux && nix develop /Users/dylan/dev/linux-dev#kernel
make defconfig && make -j"$(nproc)" && kboot
```

On native Linux, `scripts/kdev` does all of that (clone into `linux/` first).

Full setup (Mac VM or native Linux): [setup/setup.md](setup/setup.md). Details: [notes/environment.md](notes/environment.md).
