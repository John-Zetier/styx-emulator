{
  description = "Styx Emulator - Composable emulation for heterogeneous computing systems";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    crane = {
      url = "github:ipetkov/crane";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rust-overlay, crane, flake-utils, ... }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        # Rust toolchain matching Guix config
        rustToolchain = pkgs.rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" "clippy" "rustfmt" ];
          targets = [ ];
        };

        # Build cargo-nextest from source
        cargo-nextest = pkgs.cargo-nextest or (pkgs.rustPlatform.buildRustPackage rec {
          pname = "cargo-nextest";
          version = "0.9.81";
          
          src = pkgs.fetchFromGitHub {
            owner = "nextest-rs";
            repo = "nextest";
            rev = "cargo-nextest-${version}";
            hash = "0wxjhd5f30cxn8f2w24v1rynckzpsidawcvwbgssgpbvmpzf4yrs";
          };
          
          cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          
          # Important: ensure the binary is named correctly for cargo
          cargoBuildFlags = [ "--package" "cargo-nextest" ];
          cargoTestFlags = [ "--package" "cargo-nextest" ];
          
          doCheck = false;
          nativeBuildInputs = with pkgs; [ pkg-config ];
          buildInputs = with pkgs; [ zstd ];
          
          # Ensure the binary is installed with the correct name
          postInstall = ''
            # Make sure cargo-nextest is in the right place
            if [ ! -f $out/bin/cargo-nextest ]; then
              if [ -f $out/bin/nextest ]; then
                mv $out/bin/nextest $out/bin/cargo-nextest
              fi
            fi
          '';
        });

        # Build cargo-hakari
        cargo-hakari = pkgs.cargo-hakari or (pkgs.rustPlatform.buildRustPackage rec {
          pname = "cargo-hakari";
          version = "0.9.33";
          
          src = pkgs.fetchFromGitHub {
            owner = "guppy-rs";
            repo = "guppy";
            rev = "cargo-hakari-${version}";
            hash = "02mcv3aw2p2446whskwx7vgfkpxa2a39bs3gi80lv5qfgccn55m0";
          };
          
          cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          cargoBuildFlags = [ "-p" "cargo-hakari" ];
          
          doCheck = false;
          nativeBuildInputs = with pkgs; [ pkg-config ];
        });

        # Optional: cargo-llvm-cov
        cargo-llvm-cov = pkgs.cargo-llvm-cov or (pkgs.rustPlatform.buildRustPackage rec {
          pname = "cargo-llvm-cov";
          version = "0.6.14";
          
          src = pkgs.fetchFromGitHub {
            owner = "taiki-e";
            repo = "cargo-llvm-cov";
            rev = "v${version}";
            hash = "0f50bnjwx0f628rl4cgzk3lp7daqs04kw6ri7dwwi2cc6hsfg6l8";
          };
          
          cargoHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
          doCheck = false;
        });

        # Development shell environment
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            # Rust toolchain
            rustToolchain
            cargo-nextest
            cargo-hakari
            # cargo-llvm-cov
            
            # LLVM/Clang toolchain
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
            dtc  # Device tree compiler - needed for tests
            
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
            
            # Additional tools
            gnused
          ];

          # Environment variables matching Guix setup
          LIBCLANG_PATH = "${pkgs.llvmPackages_18.libclang.lib}/lib";
          
          # Rust environment
          RUST_SRC_PATH = "${rustToolchain}/lib/rustlib/src/rust/library";
          
          # For cargo to find libclang when building rust projects
          BINDGEN_EXTRA_CLANG_ARGS = "-I${pkgs.llvmPackages_18.libclang.lib}/lib/clang/${pkgs.llvmPackages_18.libclang.version}/include";

          shellHook = ''
            echo "Styx Emulator Development Environment"
            echo "Rust version: $(rustc --version)"
            echo "Clang version: $(clang --version | head -n1)"
            
            # Set up similar directory structure to Guix if needed
            export STYX_ROOT="$PWD"
            
            # Add any additional setup
            export PATH="$PWD/dist/nix/bin:$PATH"
            
            # Create link directory similar to Guix
            mkdir -p dist/nix/.links
            
            # Verify cargo-nextest is available
            if command -v cargo-nextest &> /dev/null; then
              echo "cargo-nextest: $(cargo-nextest --version)"
            else
              echo "Warning: cargo-nextest not found in PATH"
              echo "Try running: cargo install cargo-nextest"
            fi
            
            echo ""
            echo "Development environment ready. Run 'just test' to run tests."
          '';
        };

      in
      {
        # Development shell
        devShells.default = devShell;
        
        # Export packages for debugging
        packages = {
          inherit cargo-nextest cargo-hakari cargo-llvm-cov;
        };
        
        # Apps for running commands
        apps = {
          bootstrap = {
            type = "app";
            program = toString (pkgs.writeShellScript "bootstrap" ''
              echo "Environment already bootstrapped via Nix"
            '');
          };
          
          enter-shell = {
            type = "app";
            program = toString (pkgs.writeShellScript "enter-shell" ''
              echo "Use 'nix develop' to enter the development shell"
            '');
          };
        };
      });
}
