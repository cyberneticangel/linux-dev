# Submitting patches: the practical version

Condensed from `Documentation/process/submitting-patches.rst`, `submit-checklist.rst`,
`5.Posting.rst`, `6.Followthrough.rst`, `generated-content.rst` and `coding-assistants.rst`
(torvalds/linux @ a804c5742bff, 2026-10-20). When in doubt, the upstream file wins.

## TL;DR flow

```
pick base (MAINTAINERS T: tree)  →  one logical change per commit  →  every commit builds
→ checkpatch --strict  →  get_maintainer  →  b4 prep / format-patch --base  →  send
→ wait 1+ week  →  answer every review comment  →  vN+1 with changelog below ---
```

## 1. Commit message

```
subsys: component: Imperative summary under ~70-75 chars

Describe the problem first: what's wrong, the user-visible impact, how to
trigger it, and an excerpt of the oops or log if there is one. Then explain
what this patch does about it and why it's done this way. Wrap at 75 columns.
For optimisations, give numbers and the trade-off.

Fixes: 54a4f0239f2e ("KVM: MMU: make kvm_mmu_zap_page() return the number of pages it actually freed")
Closes: https://lore.kernel.org/<message-id>
Cc: stable@vger.kernel.org
Signed-off-by: Your Name <you@example.org>
---
v2: - dropped the helper (Reviewer)
v1: https://lore.kernel.org/<v1-msgid>

 drivers/foo/bar.c | 5 +++--
```

Rules that trip people up:
- **Imperative mood:** "Add X", not "This patch adds X" or "I added X".
- **Subject prefix:** copy it from `git log --oneline -- <file>` for that file
  (e.g. `arm64: dts: apple:`, `dt-bindings: iommu: apple,dart:`, `soc: apple: rtkit:`,
  `rust: kernel:`). It's the patch's globally unique ID forever. Don't use the same summary
  for several patches in a series.
- **Commit references:** at least 12 hex chars plus the subject: `commit e21d2170f366 ("video: ...")`.
  The `Fixes:` tag is never wrapped, even past 75 columns.
- **Self-contained:** v3 must carry the full description, not "see v1". Reviewers may never
  have seen v1.
- **Backtraces:** trim them to the meaningful frames. Drop timestamps, the module list and register dumps.
- **Below `---`:** per-version changelog, lore links to earlier versions and notes for the
  maintainer. Tools strip this on apply.
- **Links:** use `https://lore.kernel.org/<Message-ID>` (no angle brackets). Summarise the
  discussion in the message too; don't depend on the link alone.

### Tags

| Tag | Meaning | Needs the person's permission? |
|---|---|---|
| `Signed-off-by:` | DCO: you have the right to submit this (see below). The last SoB is the submitter | n/a, your own |
| `Co-developed-by:` | co-author; **must** be followed immediately by their SoB | yes |
| `Reviewed-by:` / `Tested-by:` / `Acked-by:` | only when given on the list; carry them into vN+1 unless the patch changed substantially (then say below `---` why you dropped them) | yes |
| `Reported-by:` + `Closes:` | credit for a bug report (not for feature requests) | implicit if they reported in public |
| `Suggested-by:` | credit for the idea | implicit if they suggested it in public |
| `Cc:` | was given the chance to comment | implicit |
| `Fixes:` | the commit that introduced the bug; it routes the fix to stable | n/a |
| `Link:` | background discussion | n/a |
| `Cc: stable@vger.kernel.org` | backport request; goes in the tag block, not the email recipients. Use `# 6.12.x` suffixes for version or prerequisite hints | n/a |

### DCO and AI / tool use (this matters for how *we* work)

- `Signed-off-by` certifies the Developer's Certificate of Origin 1.1 under a real identity.
  **Only a human can sign off. An AI assistant must never add an SoB** (`coding-assistants.rst`).
  You review everything, add your own SoB, and take full responsibility.
- `generated-content.rst`: if a meaningful amount of the code **or the changelog** came from a
  tool (an LLM, `checkpatch --fix`, a Coccinelle script, translation), **say so** in the
  changelog or cover letter: what tool, what input or prompts (summarised for long sessions),
  which parts it touched and how you tested. Spelling fixes, completion and reformatting
  are out of scope. Expect extra scrutiny, and be ready to defend every line. Maintainers
  may reject such patches outright.
- For AI-found bugs, `coding-assistants.rst` also requires a reproducer, a tested fix with a
  `Fixes:` tag, a clean checkpatch run and an explicit "what couldn't be verified" note. Use
  `threat-model.rst` to decide between `security-bugs.rst` and a normal patch.

## 2. Splitting a series

- One **logical** change per patch. A treewide mechanical change counts as one patch;
  "bug fix + optimisation" is two.
- **Every patch must build and boot** (bisectability).
- Move code in its own patch, with no edits mixed in.
- API first, then users. For DT work: **bindings → driver → DTS last** (see
  [devicetree-and-soc.md](devicetree-and-soc.md)).
- Send at most ~15 patches at a time.
- If a patch depends on another, say "depends on X" in the message.

## 3. Pre-send checklist (`submit-checklist.rst`, the parts that matter most)

- [ ] `./scripts/checkpatch.pl --strict -g <base>..`: you can justify every remaining warning.
- [ ] Builds without new warnings at `=y`, `=m`, `=n` for every Kconfig symbol you touched; also
      `allnoconfig`, `allmodconfig` and `O=builddir`. Try `W=1`.
- [ ] `make C=1` (sparse) is clean for touched files. Run `make checkstack` and look at any
      function over 512 bytes.
- [ ] Build at least one other arch or word size if the code is generic.
- [ ] Runtime-tested with the debug options together: `PREEMPT`, `DEBUG_PREEMPT`, `SLUB_DEBUG`,
      `DEBUG_PAGEALLOC`, `DEBUG_MUTEXES`, `DEBUG_SPINLOCK`, `DEBUG_ATOMIC_SLEEP`, `PROVE_RCU`,
      `DEBUG_OBJECTS_RCU_HEAD`, plus lockdep (`PROVE_LOCKING`). Shortcut: `make debug.config`.
- [ ] New Kconfig options have help text and default to off.
- [ ] Barriers have comments. You include what you use; don't rely on transitive headers.
- [ ] New uAPI or sysfs is documented in `Documentation/ABI/`, with linux-api@vger.kernel.org in Cc.
      Boot params go in `kernel-parameters.txt`. Module params get `MODULE_PARM_DESC()`.
- [ ] `make htmldocs` is clean if you touched Documentation/ or kernel-doc.
- [ ] Re-test on the latest linux-next tag.

## 4. Recipients

```sh
./scripts/get_maintainer.pl outgoing/*.patch     # or b4 prep --auto-to-cc
```

- To: the maintainers. Cc: the reviewers and lists it prints. linux-kernel@ is the default
  catch-all; don't spam unrelated lists.
- **SoC caveat (`maintainer-soc.rst`):** get_maintainer is unreliable for shared defconfigs.
  Build the Cc list from MAINTAINERS by hand.
- **Apple:** `ARM/APPLE MACHINE SUPPORT` = Sven Peter and Janne Grunau (M), Neal Gompa (R),
  asahi@lists.linux.dev, linux-arm-kernel@lists.infradead.org. Tree: AsahiLinux/linux.
  IRC: #asahi-dev on OFTC.
- **Rust:** rust-for-linux@vger.kernel.org; Miguel Ojeda (M) plus a long R: list. Zulip:
  rust-for-linux.zulipchat.com. Tree: Rust-for-Linux/linux `rust-next`.
- Exploitable security bug: security@kernel.org, never public lists (`security-bugs.rst`).
  Don't email Linus.

## 5. Formatting and sending

### Plain git

```sh
git format-patch --base=auto --cover-letter -v2 -o outgoing/ <base>
./scripts/checkpatch.pl --strict outgoing/*.patch
git send-email --to=... --cc=... outgoing/*.patch      # send to yourself first!
```

- `--base` adds a `base-commit:` trailer, which CI bots need. The base must be a public tree.
- Plain-text inline patches only: no attachments, no MIME, no HTML. See `email-clients.rst`.
- Don't chain vN as `In-Reply-To` of vN-1. Put a lore link in the cover letter instead.

### b4 (recommended: https://b4.docs.kernel.org)

```sh
b4 prep -n apple-foo -f <base>     # new topic branch with a cover-letter commit
b4 prep --edit-cover               # write the cover letter
b4 prep --auto-to-cc               # get_maintainer → To/Cc
b4 prep --check                    # checkpatch + more on every commit
b4 send --reflect                  # dry run: send only to yourself
b4 send                            # real send, via the kernel.org web endpoint or SMTP
b4 trailers -u                     # pull Reviewed-by etc. from replies into your commits
b4 prep --compare-to v1            # range-diff against what you sent
b4 am <msgid>                      # apply someone else's series from lore
b4 shazam <msgid>                  # ...and apply it straight onto the current branch
```

b4 bumps versions, records the changelog and does patatt attestation for you.

<a id="git-config"></a>
### git config (once)

```ini
[core]
    abbrev = 12
[pretty]
    fixes = Fixes: %h (\"%s\")
[format]
    signOff = false          # sign off deliberately with `git commit -s`
[sendemail]
    smtpServer = ...         # or let `b4 send` use the kernel.org web endpoint
    confirm = always
    suppressCc = self
```

`git log -1 --pretty=fixes <sha>` then prints a ready-made `Fixes:` line.

## 6. After sending

- Expect comments within 2–3 weeks. **Wait at least one week** before pinging, and longer
  during the merge window.
- After a few weeks with no change: `[PATCH vN RESEND]` (only if the patch is unchanged).
- Answer **every** comment, interleaved and trimmed, never top-posting. Thank reviewers. A
  question that doesn't lead to a code change usually means the commit message or a comment
  should explain it. Cc everyone who commented on vN+1.
- DT maintainers work from Patchwork and may miss pings on reviewed patches. Use IRC
  (`maintainer-devicetree.rst`).
- Once the patch is applied, you still own regressions in it (`handling-regressions.rst`). Fix
  them quickly; maintainers revert regressions without hesitation.
