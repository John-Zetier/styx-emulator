# Compatibility wrapper for non-flake users
{ pkgs ? import <nixpkgs> {
    overlays = [
      (import (builtins.fetchTarball {
        url = "https://github.com/oxalica/rust-overlay/archive/master.tar.gz";
      }))
    ];
  }
}:

pkgs.mkShell {
  buildInputs = with pkgs; [
    # Rust toolchain
    (rust-bin.stable.latest.default.override {
      extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
    })
    
    # LLVM/Clang 18
    llvmPackages_18.clang
    llvmPackages_18.clang-unwrapped
    llvmPackages_18.libclang
    llvmPackages_18.stdenv
    
    # Build tools
    cmake
    ninja
    gnumake
    pkg-config
    protobuf
    dtc
    
    # System tools
    coreutils
    curl
    wget
    git
    direnv
    just
    which
    gnugrep
    findutils
    bash
    gnused
    
    # Development tools
    gdb
    python3
    
    # Container tools
    docker
    docker-client
    podman
    podman-compose
    
    # Libraries
    zlib
    cacert
  ];

  LIBCLANG_PATH = "${pkgs.llvmPackages_18.libclang.lib}/lib";
  RUST_SRC_PATH = "${pkgs.rust-bin.stable.latest.default}/lib/rustlib/src/rust/library";
  
  shellHook = ''
    echo "Styx Emulator Development Environment (shell.nix)"
    echo "Rust version: $(rustc --version)"
    echo "Clang version: $(clang --version | head -n1)"
    export STYX_ROOT="$PWD"
  '';
}
