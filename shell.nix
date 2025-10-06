# Non-flake wrapper with the same toolchain/linker/runtime setup
{ pkgs ? import <nixpkgs> {
    overlays = [
      (import (builtins.fetchTarball {
        url = "https://github.com/oxalica/rust-overlay/archive/master.tar.gz";
      }))
    ];
  }
}:

let
  llvm = pkgs.llvmPackages_18;
  rustToolchain = pkgs.rust-bin.stable."1.90.0".default.override {
    extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
  };
  ccBin = "${llvm.clang}/bin/clang";
  lldBinDir = "${llvm.lld}/bin";
in
pkgs.mkShell {
  buildInputs = with pkgs; [
    rustToolchain
    llvm.clang llvm.clang-unwrapped llvm.libclang llvm.stdenv llvm.lld

    stdenv.cc.cc.lib

    cmake ninja gnumake pkg-config protobuf
    coreutils curl wget git direnv just which gnugrep findutils bash gnused
    gdb python3
    docker docker-client podman podman-compose
    zlib cacert
    dtc
  ];

  LIBCLANG_PATH = "${llvm.libclang.lib}/lib";
  RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";

  # Ensure libstdc++ is available to host build scripts
  LD_LIBRARY_PATH = pkgs.lib.makeLibraryPath [ pkgs.stdenv.cc.cc llvm.libclang ];

  # Use clang + lld (no mold)
  RUSTFLAGS    = "-Clinker=${ccBin} -C link-self-contained=no -Clink-arg=-fuse-ld=lld -Clink-arg=-Wl,--eh-frame-hdr";
  RUSTDOCFLAGS = "-Clinker=${ccBin} -C link-self-contained=no -Clink-arg=-fuse-ld=lld -Clink-arg=-Wl,--eh-frame-hdr";

  shellHook = ''
    export PATH=${lldBinDir}:$PATH
    export CC=${ccBin}
    export CXX=${llvm.clang}/bin/clang++

    echo "Styx Emulator Development Environment (shell.nix)"
    echo "Rust:  $(rustc --version)"
    echo "Clang: $(clang --version | head -n1)"
    command -v ld.lld >/dev/null && echo "lld:   $(ld.lld --version | head -n1)"
  '';
}
