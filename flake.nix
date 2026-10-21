{
  description = "Personal dev environment for upstream Linux kernel work (build, check, test, send)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { nixpkgs, rust-overlay, ... }:
    let
      systems = [
        "aarch64-darwin" # your Mac (mail/patch workflow, QEMU boots via hvf)
        "aarch64-linux" # Linux VM on the Mac (kernel builds)
        "x86_64-linux" # any other Linux box
      ];
      forAllSystems =
        f:
        nixpkgs.lib.genAttrs systems (
          system:
          f (
            import nixpkgs {
              inherit system;
              overlays = [ rust-overlay.overlays.default ];
            }
          )
        );
    in
    {
      devShells = forAllSystems (
        pkgs:
        let
          inherit (pkgs) lib;
          llvm = pkgs.llvmPackages;

          # Rust-for-Linux needs rust-src plus the usual linting tools.
          # Minimum is 1.85 (Documentation/process/changes.rst); latest stable is fine.
          rustKernel = pkgs.rust-bin.stable.latest.default.override {
            extensions = [
              "rust-src"
              "rustfmt"
              "clippy"
              "rust-analyzer"
            ];
          };

          # dt_binding_check / dtbs_check (Documentation/devicetree/bindings/writing-schema.rst).
          # Linux shell only: dtschema is marked broken on darwin.
          pythonEnv = pkgs.python3.withPackages (
            ps: with ps; [
              # dtschema now requires "pylibfdt" by name, but nixpkgs' libfdt
              # bindings (ps.libfdt, already a dependency) register under a
              # different name, so the runtime-deps check fails. Drop the check.
              (dtschema.overridePythonAttrs (old: {
                pythonRemoveDeps = (old.pythonRemoveDeps or [ ]) ++ [ "pylibfdt" ];
              }))
              yamllint
            ]
          );

          # Tiny busybox initramfs for kboot. Linux-only: it needs a Linux busybox.
          # There's no /dev/console in the archive (no mknod in the build sandbox),
          # so /init mounts devtmpfs first and then reopens the console itself.
          initramfs = pkgs.runCommand "kboot-initramfs.cpio.gz" {
            nativeBuildInputs = [
              pkgs.cpio
              pkgs.gzip
            ];
          } ''
            mkdir -p root/bin root/dev root/proc root/sys root/tmp
            cp ${pkgs.pkgsStatic.busybox}/bin/busybox root/bin/busybox
            cat > root/init <<'EOF'
            #!/bin/busybox sh
            export PATH=/bin
            /bin/busybox --install -s /bin
            mount -t devtmpfs devtmpfs /dev
            exec 0</dev/console 1>/dev/console 2>&1
            mount -t proc proc /proc
            mount -t sysfs sysfs /sys
            mount -t tmpfs tmpfs /tmp
            mount -t debugfs debugfs /sys/kernel/debug 2>/dev/null
            echo "kboot: $(uname -r) up; exit the shell to power off"
            setsid cttyhack sh
            poweroff -f
            EOF
            chmod +x root/init
            (cd root && find . | cpio -o -H newc -R 0:0 --quiet | gzip -9) > $out
          '';

          # Boot a freshly built kernel in QEMU: `kboot [extra qemu args...]`.
          kboot = pkgs.writeShellScriptBin "kboot" ''
            set -euo pipefail
            out=''${KBUILD_OUTPUT:-.}
            arch=''${ARCH:-$(uname -m)}
            case "$arch" in
              arm64|aarch64)
                arch=arm64
                image=$out/arch/arm64/boot/Image
                qemu=qemu-system-aarch64
                machine=(-M virt)
                console=ttyAMA0
                ;;
              x86_64|x86)
                arch=x86_64
                image=$out/arch/x86/boot/bzImage
                qemu=qemu-system-x86_64
                machine=()
                console=ttyS0
                ;;
              *) echo "kboot: unsupported ARCH=$arch" >&2; exit 1 ;;
            esac
            image=''${KBOOT_IMAGE:-$image}
            initrd=''${KBOOT_INITRD:-}
            if [ ! -f "$image" ]; then
              echo "kboot: no kernel at $image (build first, or set KBOOT_IMAGE / KBUILD_OUTPUT)" >&2
              exit 1
            fi
            if [ -z "$initrd" ]; then
              echo "kboot: set KBOOT_INITRD (the Linux shell sets it; on macOS copy it from the VM)" >&2
              exit 1
            fi

            host=$(uname -m)
            [ "$host" = aarch64 ] && host=arm64
            if [ "$host" = "$arch" ] && [ -w /dev/kvm ]; then
              accel=(-accel kvm -cpu host)
            elif [ "$host" = "$arch" ] && [ "$(uname -s)" = Darwin ]; then
              accel=(-accel hvf -cpu host)
            else
              accel=(-accel tcg -cpu max)
            fi

            exec "$qemu" "''${machine[@]}" "''${accel[@]}" \
              -m "''${KBOOT_MEM:-2G}" -smp "''${KBOOT_SMP:-4}" -nographic -no-reboot \
              -kernel "$image" -initrd "$initrd" \
              -append "console=$console rdinit=/init panic=-1 ''${KBOOT_APPEND:-}" \
              "$@"
          '';

          # Patch workflow tools: useful on the Mac too (mail, b4, schema checks, QEMU).
          common = with pkgs; [
            gitFull # includes git send-email
            b4 # fetch/apply/prep/send series (https://b4.docs.kernel.org)
            gnumake
            perl # scripts/checkpatch.pl, scripts/get_maintainer.pl
            codespell # checkpatch --codespell
            dtc
            qemu
            kboot
          ];
        in
        {
          # Mail/review/QEMU tooling. Works on macOS and Linux.
          default = pkgs.mkShellNoCC {
            name = "linux-tools";
            packages = common;

            shellHook = ''
              echo "linux tools shell: $(b4 --version 2>/dev/null | head -1), $(git --version)"
              echo "  kernel builds need the Linux shell:  nix develop .#kernel  (in the VM)"
            '';
          };
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          # Mainline kernel builds. Linux only: macOS' case-insensitive filesystem
          # breaks kernel trees. Build with LLVM=1 (set below); cross-compile with
          # e.g. ARCH=arm64 on an x86_64 host.
          kernel = (pkgs.mkShell.override { stdenv = llvm.stdenv; }) {
            name = "linux-kernel";
            packages =
              common
              ++ (with pkgs; [
                llvm.lld
                llvm.llvm
                llvm.clang-tools # clangd, clang-format
                pythonEnv
                rustKernel
                rust-bindgen
                bc
                bison
                flex
                openssl
                elfutils
                ncurses
                pkg-config
                cpio
                kmod
                zstd
                lz4
                xz
                pahole # CONFIG_DEBUG_INFO_BTF
                rsync # make headers_install
                # static analysis (Documentation/dev-tools/)
                sparse # make C=1 / C=2
                smatch
                coccinelle # make coccicheck
                # debugging
                gdb # with CONFIG_GDB_SCRIPTS: gdb vmlinux, then lx-symbols
                ccache
                cscope
              ]);

            # The Nix compiler wrapper's hardening flags break kernel builds.
            hardeningDisable = [ "all" ];
            LLVM = "1";
            KBOOT_INITRD = "${initramfs}";

            # The wrapped clang adds -nostdlibinc, which the kernel's -nostdinc makes
            # unused, and Makefile.clang turns that into an error. Build the kernel
            # itself with the unwrapped clang: make CC="$KERNEL_CC" (kdev does this).
            # Host tools keep the wrapped clang (HOSTCC) for libc headers.
            KERNEL_CC = "${llvm.clang-unwrapped}/bin/clang";
            # Host tools link with -fuse-ld=lld, i.e. the unwrapped lld, so they get
            # no rpath to Nix libraries; add one for the libraries they use.
            HOSTLDFLAGS = "-Wl,-rpath,${
              lib.makeLibraryPath (
                with pkgs;
                [
                  openssl
                  elfutils
                  zlib
                  zstd
                ]
              )
            }";

            shellHook = ''
              echo "kernel shell: $(clang --version | head -1), $(rustc --version)"
              echo "  check Rust support:  make CC=\"\$KERNEL_CC\" rustavailable"
              echo "  configure / build:   make CC=\"\$KERNEL_CC\" defconfig && make CC=\"\$KERNEL_CC\" -j$(nproc)"
              echo "  boot it in QEMU:     kboot"
              echo "  or all in one:       scripts/kdev (in linux-dev)"
            '';
          };
        }
      );

      formatter = forAllSystems (pkgs: pkgs.nixfmt);
    };
}
