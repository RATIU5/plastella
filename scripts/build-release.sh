#!/usr/bin/env bash
# Build an optimized release into build/release/. Invoked by `mise run build`,
# which exports APP_NAME, SDL_DIR, SDL_GLOB, and EXE_LDFLAGS.
set -euo pipefail

out=build/release
rm -rf "$out"
mkdir -p "$out"

# ship the SDL3 shared libs alongside the binary; its rpath finds them there
# shellcheck disable=SC2086 # SDL_GLOB must glob-expand
cp -a "$SDL_DIR"/$SDL_GLOB "$out/"

odin build source/release -out:"$out/$APP_NAME.bin" \
  -extra-linker-flags:"$EXE_LDFLAGS" \
  -strict-style -vet -no-bounds-check -o:speed

cp -R resources "$out/"
