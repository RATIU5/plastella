#!/usr/bin/env bash
# Build + run the standalone (non-hot-reload) debug app. Invoked by
# `mise run run`, which exports APP_NAME, SDL_DIR, SDL_GLOB, and EXE_LDFLAGS.
set -euo pipefail

out=build/debug
mkdir -p "$out"

# stage SDL3 next to the exe so its rpath finds it
# shellcheck disable=SC2086 # SDL_GLOB must glob-expand
cp -a "$SDL_DIR"/$SDL_GLOB "$out/"

odin build source/release -out:"$out/$APP_NAME.bin" \
  -extra-linker-flags:"$EXE_LDFLAGS" \
  -strict-style -vet

# symlink so resources/ is reachable by relative path (exe chdirs to its own dir)
rm -rf "$out/resources" && ln -s ../../resources "$out/resources"

./"$out/$APP_NAME.bin"
