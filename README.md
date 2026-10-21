# linux-dev

Personal environment and notes for upstream Linux kernel work. It's the sibling of
`../asahi-dev` (m1n1 / Asahi bring-up).

```
flake.nix    dev shells: default (Mac + Linux: b4, send-email, QEMU, kboot)
             and .#kernel (Linux only: LLVM, Rust, bindgen, dtschema, sparse, smatch, cocci, gdb)
.envrc       direnv: `use flake`
notes/       kernel process / style / DT / testing notes; start at notes/README.md
linux/       kernel checkout (gitignored)
```

Quick start (in the aarch64 Linux VM):

```sh
nix develop .#kernel
git clone https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux.git linux && cd linux
make defconfig && make -j"$(nproc)" && kboot
```

Details: [notes/environment.md](notes/environment.md).
