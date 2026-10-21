# Getting started: a roadmap from a security background

The kernel is ~40M lines. Don't try to "learn the kernel": get a fast build-boot-debug loop,
then go deep on one narrow path at a time, starting with the parts a security person already
understands from the attacker's side. Paths are relative to the kernel tree (`linux/`), checked
against torvalds/linux @ `a804c5742bff`.

| Phase | Goal | Rough time |
|---|---|---|
| [1. The loop](#phase-1-the-build-boot-debug-loop) | Change code, boot it, see it, debug it | 1 week |
| [2. Security paths](#phase-2-learn-the-kernel-through-security-code) | Read real code paths end to end | 3–5 weeks |
| [3. Sanitizers and syzbot](#phase-3-sanitizers-and-syzbot-bugs) | Reproduce and root-cause real bugs | ongoing |
| [4. First patch](#phase-4-send-a-first-patch) | Get through the upstream workflow once | in parallel with 2–3 |
| [5. Exploitation](#phase-5-exploitation-and-mitigations) | Connect it back to offensive work | after 3 |

Keep a log (`notes/log.md` or similar) of every path you trace and every bug you reproduce. It
becomes your reference and, later, the material for commit messages.

---

## Phase 1: the build-boot-debug loop

Setup: [`../setup/linux/README.md`](../setup/linux/README.md) (native, no VM). Commands below
assume the repo root and `scripts/kdev`. See [environment.md](environment.md) for the details.

### 1.1 Build and boot a stock kernel

```sh
scripts/kdev                  # defconfig + kvm_guest.config, build into build/x86_64, boot
```

In the busybox shell: `cat /proc/version`, `dmesg | head -50`, `cat /proc/cmdline`. Exit the
shell (or `Ctrl-a x`) to power off. **Done when:** you can rebuild and reboot in under a minute
after a one-line change (incremental builds are fast; the first one isn't).

### 1.2 Print something from the kernel

Add a line to `start_kernel()` in `init/main.c`:

```c
pr_info("hello from my kernel\n");
```

Run `scripts/kdev` (not `-n`, which boots the old image without rebuilding), then
`dmesg | grep hello`. Then do the same in a syscall you can trigger from the shell: put a
`pr_info("openat: %s\n", ...)` in `do_sys_openat2()` (`fs/open.c`). Note how noisy it is, then
revert it. Lesson: printk debugging works, but think about where you put it.

### 1.3 Write a built-in "module"

kboot's initramfs only contains busybox, so loading your own `.ko` files isn't wired up yet.
Build the code into the kernel instead; `module_init()` then runs at boot:

```sh
mkdir -p linux/drivers/misc/hello      # scratch only, never send this
```

`drivers/misc/hello/hello.c`:

```c
// SPDX-License-Identifier: GPL-2.0
#include <linux/init.h>
#include <linux/module.h>

static int __init hello_init(void)
{
	pr_info("hello: loaded\n");
	return 0;
}
module_init(hello_init);

MODULE_DESCRIPTION("Scratch hello world");
MODULE_LICENSE("GPL");
```

Add `obj-y += hello/` to `drivers/misc/Makefile` and `obj-y += hello.o` to
`drivers/misc/hello/Makefile`. Rebuild, boot, `dmesg | grep hello`. Stretch: expose a file in
`/sys/kernel/debug/` or a misc device in `/dev` and read it from the busybox shell
(`samples/kobject/` shows the sysfs version).

### 1.4 Debug with gdb

```sh
scripts/kdev -r -c "defconfig kvm_guest.config debug.config"   # DEBUG_INFO, KASAN, lockdep, ...
scripts/kdev -g                                                # terminal 1: waits for gdb
gdb build/x86_64/vmlinux -ex 'target remote :1234'             # terminal 2
```

```
(gdb) break __x64_sys_openat
(gdb) continue
(gdb) bt
(gdb) finish
```

Step from the syscall entry into `do_sys_openat2()` and on into the VFS. Try the gdb scripts too
(`make O=../build/x86_64 scripts_gdb`, then `lx-dmesg`, `lx-ps`). Reference:
`Documentation/process/debugging/gdb-kernel-debugging.rst`.

### 1.5 Run tests

```sh
cd linux
./tools/testing/kunit/kunit.py run                    # KUnit: fast unit tests, UML by default
./tools/testing/kunit/kunit.py run --arch=x86_64 'landlock*'
```

**Phase 1 is done when** you can, without looking anything up: change a line, rebuild, boot,
find your output, and attach gdb at a breakpoint.

---

## Phase 2: learn the kernel through security code

For each topic: read the docs, then **trace one concrete path from the syscall to the check**,
with gdb or by reading, and write the call chain in your log. One deep trace beats ten skims.

Navigation: `make O=../build/x86_64 compile_commands.json` for clangd in your editor, `git grep`,
and https://elixir.bootlin.com for cross-references in the browser.

### 2.1 The user/kernel boundary

- Read: `include/linux/uaccess.h` (`copy_from_user()`, `copy_to_user()`, `get_user()`), and
  `strncpy_from_user()` in `lib/strncpy_from_user.c`.
- Trace: `openat()` from `SYSCALL_DEFINE4(openat, ...)` in `fs/open.c` → `do_sys_openat2()` →
  `getname()` (copying the path from userspace) → `do_filp_open()` → `vfs_open()` →
  `security_file_open()` (the LSM hook, `security/security.c`).
- Questions to answer: Where can a userspace pointer be dereferenced directly, and why must it
  never be? What do `__user` annotations and `sparse` (`make C=1`) catch? What does SMAP add?

### 2.2 Credentials and privilege

- Read: `include/linux/cred.h`, `kernel/cred.c` (`prepare_creds()` / `commit_creds()`),
  `kernel/capability.c` (`capable()`, `ns_capable()`), `Documentation/security/credentials.rst`.
- Trace: what happens on `setuid()` (`kernel/sys.c`) and how a privileged operation checks
  `capable(CAP_SYS_ADMIN)`.
- Questions: Why are creds copy-on-write and RCU-protected? Why is overwriting `cred` a classic
  exploit target, and what has been done to make that harder?

### 2.3 Sandboxing: seccomp and Landlock

These are small, readable and security-focused, with tests and samples. Do both.

- **seccomp:** `kernel/seccomp.c`, `Documentation/userspace-api/seccomp_filter.rst`,
  `samples/seccomp/`, tests in `tools/testing/selftests/seccomp/seccomp_bpf.c`. Trace how a
  filter runs on syscall entry (`__seccomp_permit_syscall()`).
- **Landlock:** `security/landlock/` (start with `syscalls.c`, then `ruleset.c`, `fs.c`),
  `Documentation/userspace-api/landlock.rst` and `Documentation/security/landlock.rst`. The
  sample `samples/landlock/sandboxer.c` is a good read. Landlock is unprivileged, so you can
  build and run the sandboxer on your host to see it work.
- Questions: How does Landlock attach a ruleset to a task and enforce it on a file open? How do
  the two compose with each other and with LSMs like SELinux (`Documentation/admin-guide/LSM/`)?

### 2.4 Memory and allocators

- Read: the slab allocator API (`kmalloc()` / `kfree()`, `include/linux/slab.h`), then skim
  `mm/slub.c` for freelists and caches. Don't try to read all of `mm/`.
- Questions: What is a slab cache, and why does cache isolation matter for use-after-free
  exploitation? What do `CONFIG_SLAB_FREELIST_HARDENED` and `CONFIG_RANDOM_KMALLOC_CACHES` do?

### 2.5 Mitigations

- Read: `security/Kconfig.hardening` and `kernel/configs/hardening.config` (the Kconfig help
  texts are the best summary), then `Documentation/security/self-protection.rst`.
- Exercise: build with `scripts/kdev -r -c "defconfig kvm_guest.config hardening.config"` and
  check `/proc/kallsyms` as non-root, KASLR across boots, and `dmesg` restrictions.

**Phase 2 is done when** you can draw, from memory, the path from a userspace `open()` to the
LSM hook, and explain how seccomp and Landlock each block something.

---

## Phase 3: sanitizers and syzbot bugs

This is where a security background pays off most.

### 3.1 Sanitizers

`debug.config` already enables KASAN (generic, inline), UBSAN and lockdep (`PROVE_LOCKING`).
Read `Documentation/dev-tools/kasan.rst` and learn to read a KASAN report: the bad access, the
allocation stack and the free stack. Then deliberately trigger one in your scratch module (an
out-of-bounds write on a `kmalloc()` buffer, then a use-after-free) and read the reports.
`mm/kasan/kasan_test_c.c` has many examples.

### 3.2 Reproduce a syzbot bug

syzbot (https://syzkaller.appspot.com/upstream) fuzzes the kernel continuously and publishes
crashes with reproducers.

1. Pick an open bug that has a **C reproducer**, is on x86_64, and is a simple class: a
   `WARNING`, a `KASAN: slab-out-of-bounds` or a `general protection fault` in a subsystem you
   can build. Avoid races, networking-heavy and filesystem-image bugs at first.
2. Build a kernel with the bug's `.config` (linked from the report) or with `debug.config` plus
   the subsystem's options.
3. Run the reproducer in the guest. kboot's busybox initramfs can't run it yet (TODO: let kboot
   add files to the initramfs), so for now extend the initramfs or use a small Debian image.
   Build the reproducer statically: `gcc -static -o repro repro.c`.
4. Reproduce the crash, then **find the root cause** with gdb, `pr_info()` and the KASAN stacks.
   Write it up in your log in the shape of a commit message: what goes wrong, why, since when
   (`git log -S` / `git blame` to find the commit that introduced it).
5. If you have a fix, test it with syzbot itself (`#syz test` by email, see the syzbot docs)
   before sending.

Also read the syzkaller docs on how it finds bugs (`docs/` in
https://github.com/google/syzkaller), since you'll eventually want to run it yourself.

**Phase 3 is ongoing.** Early goal: one bug reproduced and root-caused, even if someone else
fixes it first.

---

## Phase 4: send a first patch

Do this in parallel with phases 2–3. The upstream workflow is a skill of its own, so learn it on
something low-stakes.

1. Pick a small, real fix. [first_contributions.md](first_contributions.md) has a ready
   candidate (the stale kernel-doc in `drivers/phy/apple/atc.c`), and `scripts/kernel-doc`,
   `checkpatch.pl` or `make W=1` warnings in a subsystem you're reading are good sources.
   Avoid pure whitespace and checkpatch cleanups in old code; many maintainers reject those.
2. Check it isn't already fixed: the maintainer's tree (`T:` in `MAINTAINERS`), linux-next and
   https://lore.kernel.org.
3. Follow [submitting-patches.md](submitting-patches.md): base on the maintainer's tree, write
   a commit message that explains *why*, run checkpatch, and send with `b4`.
4. **AI rules:** only you sign off, and you must disclose meaningful tool involvement
   (`Documentation/process/coding-assistants.rst`, `generated-content.rst`).
5. Answer every review comment, and wait a week before pinging.

---

## Phase 5: exploitation and mitigations

Once you can read and debug kernel code comfortably, connect it back to offensive work:

- Google's kernelCTF write-ups (https://google.github.io/security-research/kernelctf/rules.html
  and linked exploits) and Project Zero's kernel posts.
- Take a public, fixed CVE with a write-up, check out the vulnerable commit, reproduce it in
  QEMU, then read the fix and check which mitigation from 2.5 would have blocked it.
- Security fixes go through security@kernel.org, not public lists:
  `Documentation/process/security-bugs.rst`. Read it before you ever report one.

---

## Reading list

| What | Why |
|---|---|
| *Linux Kernel Development*, Robert Love | Concepts: processes, scheduling, syscalls, memory. Old but still the best overview |
| *Linux Kernel Programming*, Kaiwan Billimoria | Hands-on modules, memory, sync; more current |
| https://lwn.net/Kernel/ (weekly) | How the kernel actually works and changes; excellent security coverage |
| `Documentation/process/development-process.rst` | How upstream works (chapters 1–8) |
| `Documentation/security/` | Credentials, self-protection, LSM, Landlock |
| `Documentation/dev-tools/` | KASAN, KCSAN, KUnit, kcov, sparse, Coccinelle |

## What to skip for now

The scheduler internals, most of `mm/`, arch boot code, and Apple / devicetree bring-up. They
make sense once phases 1–3 feel routine; then [devicetree-and-soc.md](devicetree-and-soc.md) is
the next step toward the Asahi work.
