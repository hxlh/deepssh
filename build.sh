#!/usr/bin/env bash
set -euo pipefail

APP_NAME="deepssh"
DIST_DIR="dist"

usage() {
  cat <<'EOF'
Usage:
  ./build.sh fmt
  ./build.sh build [--debug|--profile|--release]
  ./build.sh package [--debug|--profile|--release]

Defaults:
  build   -> --debug
  package -> --release
EOF
}

mode_from_args() {
  local default_mode="$1"
  shift
  local mode="$default_mode"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --debug)
        mode="debug"
        ;;
      --profile)
        mode="profile"
        ;;
      --release)
        mode="release"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        echo "Unknown option: $1" >&2
        usage >&2
        exit 1
        ;;
    esac
    shift
  done

  printf '%s' "$mode"
}

platform_name() {
  case "$(uname -s)" in
    Darwin*) printf 'macos' ;;
    Linux*) printf 'linux' ;;
    MINGW*|MSYS*|CYGWIN*) printf 'windows' ;;
    *)
      echo "Unsupported platform: $(uname -s)" >&2
      exit 1
      ;;
  esac
}

arch_name() {
  case "$(uname -m)" in
    x86_64|amd64) printf 'x64' ;;
    arm64|aarch64) printf 'arm64' ;;
    *) uname -m ;;
  esac
}

mode_dir_name() {
  case "$1" in
    debug) printf 'Debug' ;;
    profile) printf 'Profile' ;;
    release) printf 'Release' ;;
    *)
      echo "Unsupported mode: $1" >&2
      exit 1
      ;;
  esac
}

flutter_mode_arg() {
  printf -- '--%s' "$1"
}

cargo_mode_arg() {
  case "$1" in
    debug) printf '' ;;
    profile|release) printf -- '--release' ;;
    *)
      echo "Unsupported mode: $1" >&2
      exit 1
      ;;
  esac
}

cargo_target_dir() {
  case "$1" in
    debug) printf 'debug' ;;
    profile|release) printf 'release' ;;
    *)
      echo "Unsupported mode: $1" >&2
      exit 1
      ;;
  esac
}

run_fmt() {
  cargo fmt --manifest-path rust/Cargo.toml
  dart format lib test
  flutter_rust_bridge_codegen generate
  flutter analyze
}

run_build() {
  local mode="$1"
  local platform
  platform="$(platform_name)"
  cargo build $(cargo_mode_arg "$mode") --manifest-path rust/Cargo.toml
  flutter build "$platform" "$(flutter_mode_arg "$mode")"
}

build_output_dir() {
  local platform="$1"
  local arch="$2"
  local mode="$3"
  local mode_dir
  mode_dir="$(mode_dir_name "$mode")"

  case "$platform" in
    windows)
      printf 'build/windows/%s/runner/%s' "$arch" "$mode_dir"
      ;;
    macos)
      printf 'build/macos/Build/Products/%s' "$mode_dir"
      ;;
    linux)
      printf 'build/linux/%s/%s/bundle' "$arch" "$mode"
      ;;
    *)
      echo "Unsupported platform: $platform" >&2
      exit 1
      ;;
  esac
}

run_package() {
  local mode="$1"
  local platform arch source target
  platform="$(platform_name)"
  arch="$(arch_name)"

  run_build "$mode"

  source="$(build_output_dir "$platform" "$arch" "$mode")"
  target="$DIST_DIR/$APP_NAME-$platform-$arch-$mode"

  if [[ ! -d "$source" ]]; then
    echo "Build output not found: $source" >&2
    exit 1
  fi

  rm -rf "$target"
  mkdir -p "$target"

  if [[ "$platform" == "macos" ]]; then
    shopt -s nullglob
    local apps=("$source"/*.app)
    shopt -u nullglob
    if [[ ${#apps[@]} -eq 0 ]]; then
      echo "macOS app bundle not found in: $source" >&2
      exit 1
    fi
    cp -R "${apps[@]}" "$target/"
    local rust_lib="rust/target/$(cargo_target_dir "$mode")/libdeepssh_rust.dylib"
    for app in "${apps[@]}"; do
      local app_name
      app_name="$(basename "$app")"
      local frameworks_dir="$target/$app_name/Contents/Frameworks"
      mkdir -p "$frameworks_dir"
      cp "$rust_lib" "$frameworks_dir/"
    done
  else
    cp -R "$source"/. "$target/"
  fi

  echo "Packaged: $target"
}

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 1
fi

command="$1"
shift

case "$command" in
  fmt)
    if [[ $# -ne 0 ]]; then
      echo "fmt does not accept options." >&2
      usage >&2
      exit 1
    fi
    run_fmt
    ;;
  build)
    run_build "$(mode_from_args debug "$@")"
    ;;
  package)
    run_package "$(mode_from_args release "$@")"
    ;;
  -h|--help)
    usage
    ;;
  *)
    echo "Unknown command: $command" >&2
    usage >&2
    exit 1
    ;;
esac
