# How kernel development flows

Sources: `Documentation/process/2.Process.rst`, `howto.rst`, `stable-kernel-rules.rst`,
`handling-regressions.rst`, `maintainer-soc.rst`.

## Release cycle (about 9–10 weeks)

```
vX.Y released ─► merge window (2 wk) ─► X.Y+1-rc1 ─► rc2 … rc7(/rc8) weekly ─► X.Y+1 released
                 maintainers send PRs       only fixes go to mainline
                 to Linus; ~1000 commits/day
```

- **Features must already be in a maintainer tree (and linux-next) before the merge window
  opens.** Many maintainers close their `-next` branch for features around -rc6 or -rc7
  (convention, not documented; it varies per tree), so code you want in X.Y+1 needs to be
  reviewed during the X.Y rc phase.
- After -rc1, mainline takes fixes only. A new driver for previously unsupported hardware is
  sometimes an exception, because it can't regress anything.
- **During the merge window,** maintainers are busy. New series sent then tend to sit until
  -rc1. Bug fixes are still fine.
- **Where we are (2026-10-21):** v7.3 is out (Makefile `7.3.0`, "Baby Opossum Posse") and the
  7.4 merge window is open (pulls like `lsm-pr-20261016` landing on 2026-10-20). Expect
  7.4-rc1 around 2026-11-01 and 7.4 final around late December. A series reviewed during the
  7.4 rcs is aiming at 7.5.

## Trees

| Tree | What it is |
|---|---|
| `torvalds/linux.git` | mainline. Patches arrive almost only via maintainer pull requests |
| subsystem trees (`T:` in MAINTAINERS) | **where your patches get applied**. Base your work on them |
| `linux-next` | daily merge of all `-next` branches. Integration testing, and where conflicts show up early |
| `stable/linux.git` | X.Y.z backports (Greg KH, Sasha Levin) |
| `soc/soc.git` | arm/arm64/RISC-V DTS, defconfigs, `drivers/soc` etc. Fed by per-platform trees |
| `AsahiLinux/linux` (`asahi` branch) | downstream Apple tree; carries most Apple work long before it lands upstream |
| `Rust-for-Linux/linux` `rust-next` | Rust core infrastructure |

**Apple SoC path:** platform patches go to the Apple maintainers (Sven Peter, Janne Grunau).
They send PRs to soc@kernel.org with DTS, driver and defconfig changes on separate branches,
and the SoC maintainers send them to Linus. Bindings plus a driver for a new IP block go
through *that driver's subsystem tree* (i2c, iommu, ...), never through the SoC tree.

**What's upstream (@ a804c5742bff):** `arch/arm64/boot/dts/apple/` covers the A7–A11 (s5l/s8000…),
M1 (t8103, t600x), M2 (t8112, t602x) and M3 (t8122, t603x). **No T8132 (M4), T8140 (A18 Pro)
or T8142 (M5) yet.** Those exist only downstream in linux-asahi.

## Patch lifecycle

```
design (RFC if unsure) → early review on list → vN iterations → maintainer applies to -next
→ linux-next soak → merge window PR → mainline → (if Fixes:/Cc: stable) stable backport
```

- **RFC:** for "is this the right approach?" posts. Maintainers often skip RFCs for detailed
  review; DT Patchwork marks them as such.
- Post early. Silence usually means wrong recipients or bad timing, not rejection.
- **Never break userspace,** and that includes DT ABI (`bindings/ABI.rst`): an old DTB must keep
  working with a new kernel.

## Stable

Three ways to get a fix into stable (`stable-kernel-rules.rst`):
1. **Preferred:** put `Cc: stable@vger.kernel.org` (and ideally `Fixes:`) in the tag block of
   the mainline patch. It's picked up automatically after it lands. Use `# 6.12.x` or
   `# <sha>: prereq` comments for hints.
2. Ask stable@ to pick an already-merged commit.
3. Send a backport (needed when it doesn't apply cleanly).

Rules: the fix must already be in mainline, fix a real bug users hit, and be small. Unpublished
vulnerabilities use `Cc: stable@kernel.org` (a black hole, to avoid leaking) and go through
`security-bugs.rst`.

## Regressions

`handling-regressions.rst`: regressions get top priority. Report them with `#regzbot introduced: <sha>`
on the list so regzbot tracks them. If your commit caused one, expect to fix it fast or see it
reverted.

## Etiquette / community

- Interleaved, trimmed replies. No top-posting, no HTML.
- Code of conduct: `code-of-conduct.rst` plus its interpretation doc.
- Don't send private review requests. Use the lists so the discussion is archived on lore.
- Contacts for our areas: #asahi-dev (OFTC), Rust-for-Linux Zulip, #devicetree / #armlinux (libera).
