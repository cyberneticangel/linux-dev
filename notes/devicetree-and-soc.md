# Devicetree, bindings and SoC upstreaming

The most relevant file for Apple bring-up. Sources: `Documentation/devicetree/bindings/`
(`submitting-patches.rst`, `writing-bindings.rst`, `writing-schema.rst`, `dts-coding-style.rst`,
`ABI.rst`), `Documentation/process/maintainer-soc.rst`, `maintainer-soc-clean-dts.rst`,
`maintainer-devicetree.rst`, `Documentation/arch/arm64/booting.rst`.

## Mental model

- **A binding** (`Documentation/devicetree/bindings/**/vendor,device.yaml`) is an **ABI
  contract** between the DT and every OS or bootloader that uses it, not just Linux. It
  describes the hardware, never the driver.
- **DTS/DTSI** (`arch/arm64/boot/dts/apple/`) describes a board and must validate against the
  bindings.
- They're merged by different people: bindings go with the driver (subsystem tree), and DTS
  goes through the platform → SoC tree.

## Series layout for "new Apple block X"

```
[PATCH 1/4] dt-bindings: <subsys>: Add Apple <X>               → devicetree@, DT maintainers
[PATCH 2/4] <subsys>: Add Apple <X> driver                     → subsystem maintainer
[PATCH 3/4] arm64: dts: apple: t8103: Add <X> nodes            → Apple maintainers / SoC
[PATCH 4/4] MAINTAINERS: add Apple <X> files to ARM/APPLE      (often folded into 1/2)
```

- The binding patch is separate and comes **before** the code that uses it.
- DTS patches go **last**, or in a separate series that references the bindings on lore. The
  DTS is applied via another tree, so other orders look non-bisectable.
- Every compatible used in a DTS must be documented first; checkpatch warns otherwise.
- Binding subject: `dt-bindings: <dir>: ...`. ASoC, media, regulator, SCSI, SPI and UFS use
  `<dir>: dt-bindings: ...`. Don't write "YAML", "doc" or "binding" in the subject.
  Conversions: `dt-bindings: foo: vendor,dev: Convert to DT schema`.
- License for new bindings: `# SPDX-License-Identifier: (GPL-2.0-only OR BSD-2-Clause)`.
- Brand-new SoC platform: post to the lists first. After positive review, send one set to
  soc@kernel.org with the Kconfig entry, DTS, MAINTAINERS and optional initial drivers.

## Binding design rules (writing-bindings.rst)

**Compatibles**
- Use SoC-specific compatibles: `"apple,t8142-foo", "apple,t8103-foo"`. Put a fallback after
  the specific string **only if** software can really drive the device through the fallback.
  No wildcards, family names or `-v2` versioning. Prefer `vendor,soc1234-i2c`.
- New features or quirks mean a new compatible. Don't add a property to avoid a compatible, or
  one that the compatible already implies.
- If a documented compatible isn't yet matched by any driver, also list one that is.
- If devices look compatible in the diff but aren't, explain why in the commit message.

**Properties**
- Make the binding complete even if the driver ignores parts (e.g. describe the interrupt
  even if the driver polls).
- Reference common properties rather than redefining them. Vendor-prefix custom ones
  (`apple,foo`). Use standard unit suffixes (`-microvolt`, `-hz`, ...). Constrain everything:
  item counts, enums and order are all ABI.
- Multiple phandles need explicit order plus `*-names`, with no suffixes ("tx", not "txirq").
- If you include another schema (e.g. `i2c-controller.yaml`), use `unevaluatedProperties: false`;
  otherwise use `additionalProperties: false`.
- No instance-index properties and no custom aliases. Don't use `syscon` alone, and don't use
  `simple-mfd`/`simple-bus` for non-trivial devices.
- Don't create nodes just to instantiate drivers. One node can provide several things (clocks
  and resets, say).
- Node names aren't ABI; use phandles or compatibles to find siblings.
- File name = compatible: `apple,foo.yaml`.

**DTS**
- All MMIO devices go under a bus node. Use non-empty `ranges`.

## DTS coding style (dts-coding-style.rst)

- Names use `[a-z0-9-]`; labels use `[a-z0-9_]`. Unit addresses are lowercase hex without
  leading zeros; `reg` values are lowercase hex, padding allowed.
- **Node order:** by unit address on a bus (some platforms group by type); otherwise
  alphanumerically. `&label` overrides in a board file go alphabetically or in DTSI order.
- **Property order:** `device_type`, `compatible`, `reg`, `ranges`, standard props, vendor props,
  then a blank line and `status` last. Natural sort within each group. A blank line before
  each child node.
- One `<>` per entry in multi-cell arrays; align continuation lines with the first `<`.
- File layout: `$soc.dtsi` (only what's on the SoC), then optional shared `.dtsi`
  (`t8103-jxxx.dtsi`), then `$soc-$board.dts` (`t8103-j274.dts`). Board components belong in
  the board DTS.

## Validation (must be clean before sending)

```sh
make dt_binding_check DT_SCHEMA_FILES=apple,foo.yaml     # schema + example
make dtbs_check W=1 DT_SCHEMA_FILES=apple,foo.yaml       # real DTBs against schemas
make CHECK_DTBS=y apple/t8103-j274.dtb                   # a single board
scripts/dtc/dt-check-style --mode=strict foo.yaml        # style checker (relaxed is the default)
```

- New platform or DTS work: **no new `dtbs_check` warnings**. Some platforms require `W=1`
  (`maintainer-soc-clean-dts.rst`, opted into via MAINTAINERS). For split series, linux-next
  results are what count.
- The binding's example must pass `dt-check-style` in **strict** mode. New DTS code: no
  warnings in relaxed mode, and most strict-mode warnings fixed (strict can give false
  positives).
- `dtbs_check` skips broken schemas, so always run `dt_binding_check` too.
- Tools: `dtschema` (provides `dt-validate` etc.) and `yamllint`. Both are in the kernel shell.

## Dependencies between driver and DTS branches

When a DTS needs a header in `include/dt-bindings/` that is merged elsewhere, the options
(`maintainer-soc.rst`) are:
- avoid new binding headers when the numbers come from a datasheet;
- use literal numbers now and switch to macros a release later;
- delay the DTS by one release;
- use a shared immutable branch;
- add `#ifndef` duplicate defines and remove them later.

Changes that break old kernels must be called out explicitly, and the DTS must wait for the
driver to land.

## Defconfig

Add options to `arch/arm64/configs/defconfig` **only for upstream-supported boards**, and say
which board needs them. These go to the Apple maintainers as their own patches/branch.

## arm64 boot protocol (what m1n1 must provide; booting.rst)

- `x0` = physical address of the DTB, `x1`–`x3` = 0.
- MMU off. D-cache may be off or on, but the image range must be cleaned to PoC. The I-cache
  must not hold stale entries.
- All of DAIF masked. Non-secure EL2 (recommended, needed for KVM) or EL1.
- `CNTFRQ` programmed, `CNTVOFF` consistent across CPUs. DMA devices quiesced.
- The image is a 64-byte header (`text_offset`, `image_size`, flags) and is loaded 2 MiB-aligned.
  The DTB is 8-byte aligned and ≤2 MiB. Secondaries come up via PSCI or spin-table (Apple
  uses spin-table via `cpu-release-addr`, which m1n1 fills in).
- On Apple machines m1n1 (stage 1) chainloads m1n1 or U-Boot, which loads the kernel. m1n1's
  `kboot.c` turns the Apple ADT into the FDT fixups the kernel expects. See
  `../asahi-dev/notes/m1n1-starter-guide.md`.

## Apple-specific pointers (MAINTAINERS `ARM/APPLE MACHINE SUPPORT`)

- Bindings: `Documentation/devicetree/bindings/arm/apple.yaml` (board compatibles; **add new
  boards here**), `arm/apple/*`, and `*/apple,*` across subsystems (aic, dart, sart, nvme-ans,
  pmgr, pinctrl, i2c, spi, spmi, wdt, smc, mailbox, ...).
- Drivers: `drivers/soc/apple/` (rtkit, sart, mailbox), `drivers/irqchip/irq-apple-aic.c`,
  `drivers/iommu/apple-dart.c`, `drivers/pmdomain/apple/`, `drivers/pinctrl/pinctrl-apple-gpio.c`,
  `drivers/nvme/host/apple.c`, `drivers/mfd/macsmc.c` and friends,
  `drivers/cpufreq/apple-soc-cpufreq.c`, `drivers/watchdog/apple_wdt.c`.
- An M5 (T8142) bring-up series would, at minimum, add `apple,t8142` plus board compatibles
  to `apple.yaml`, SoC compatibles to each block's binding (AIC, pinctrl, pmgr, wdt, uart
  `apple,s5l-uart`, ...), `t8142.dtsi` plus a board `.dts`, a Makefile entry,
  and possibly irqchip changes. Use the T8140/T8132 work in linux-asahi as the template.
