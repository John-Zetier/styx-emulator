{
  description = "Styx Emulator - Nix dev env matching Guix: Rust 1.90.0, LLVM/Clang 18, lld (no mold)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs { inherit system overlays; };
        llvm = pkgs.llvmPackages_18;

        rustToolchain = pkgs.rust-bin.stable."1.90.0".default.override {
          extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
        };

        ccBin = "${llvm.clang}/bin/clang";
        lldBinDir = "${llvm.lld}/bin";
      in
      {
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            rustToolchain
            llvm.clang
            llvm.clang-unwrapped
            llvm.libclang
            llvm.stdenv
            llvm.lld

            # C++ runtime needed at runtime for host build-scripts (libstdc++.so.6)
            stdenv.cc.cc.lib

            # Build tools & utilities (same tech as Guix setup)
            cmake ninja gnumake pkg-config protobuf
            coreutils curl wget git direnv just which gnugrep findutils bash gnused
            gdb python3
            docker docker-client podman podman-compose
            zlib cacert
	    dtc
          ];

          # Make lld discoverable and set clang as the Rust linker (no mold)
          RUSTFLAGS    = "-Clinker=${ccBin} -C link-self-contained=no -Clink-arg=-fuse-ld=lld -Clink-arg=-Wl,--eh-frame-hdr";
          RUSTDOCFLAGS = "-Clinker=${ccBin} -C link-self-contained=no -Clink-arg=-fuse-ld=lld -Clink-arg=-Wl,--eh-frame-hdr";

          # Let host executables (build.rs, doctests) find libstdc++.so.6
          LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc llvm.libclang ];

          LIBCLANG_PATH = "${llvm.libclang.lib}/lib";
          RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";

          shellHook = ''
            export PATH=${lldBinDir}:$PATH
            export CC=${ccBin}
            export CXX=${llvm.clang}/bin/clang++

            echo "Styx Emulator Development Environment"
            echo "Rust:  $(rustc --version)"
            echo "Clang: $(clang --version | head -n1)"
            command -v ld.lld >/dev/null && echo "lld:   $(ld.lld --version | head -n1)"

            export STYX_ROOT="$PWD"
            mkdir -p dist/nix/.links
            export PATH="$PWD/dist/nix/bin:$PATH"

            echo ""
            echo "Environment ready. Examples:"
            echo "  just cargo-doc-test"
          '';
        };
      });
}
