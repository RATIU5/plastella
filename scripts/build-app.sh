#!/usr/bin/env bash
# Compile source/ into the reloadable app DLL. Invoked by `mise run build-app`,
# which exports APP_NAME, HR_OUT, DLL_EXT, SDL_DIR, SDL_GLOB, and SDL_LDFLAGS.
set -euo pipefail

mkdir -p "$HR_OUT"

# stage the SDL3 shared libs next to the dll so its rpath (@loader_path / $ORIGIN)
# resolves at load time; cp -a keeps version symlinks. $SDL_GLOB expands here.
# shellcheck disable=SC2086 # SDL_GLOB must glob-expand
cp -a "$SDL_DIR"/$SDL_GLOB "$HR_OUT/"

# compile to a temp name first, then atomic-rename so the host never loads a
# half-written dll. The final name must match what source/app/app.odin load()s.
odin build source/app \
  -extra-linker-flags:"$SDL_LDFLAGS" \
  -build-mode:dll -out:"$HR_OUT/${APP_NAME}_tmp$DLL_EXT" \
  -strict-style -vet -debug
mv "$HR_OUT/${APP_NAME}_tmp$DLL_EXT" "$HR_OUT/$APP_NAME$DLL_EXT"
