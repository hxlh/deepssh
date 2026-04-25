#!/usr/bin/env bash
set -euo pipefail

cargo fmt --manifest-path rust/Cargo.toml
dart format lib test
flutter_rust_bridge_codegen generate
flutter analyze
