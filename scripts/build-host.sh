#!/usr/bin/env bash
# Compile the hot-reload host executable. Invoked by `mise run build-host`,
# which exports HR_OUT and EXE.
# The host links no SDL (it only dlopen's the app dll); libSDL3 is staged into
# $HR_OUT by build-app.
set -euo pipefail

mkdir -p "$HR_OUT"

# macOS GUI processes need an embedded Info.plist section
extra=()
[ "$(uname -s)" = Darwin ] && extra=(-extra-linker-flags:"-sectcreate __TEXT __info_plist Info.plist")

odin build source/host -out:"$HR_OUT/$EXE" "${extra[@]}" -strict-style -vet -debug

# symlink so resources/ is reachable by relative path (exe chdirs to its own dir)
rm -rf "$HR_OUT/resources" && ln -s ../../resources "$HR_OUT/resources"
