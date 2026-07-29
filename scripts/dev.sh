#!/usr/bin/env bash
# Run the hot-reload loop: host in the foreground, source watcher in the back.
# Invoked by `mise run dev` (after build-app + build-host), which exports
# APP_NAME, HR_OUT, DLL_EXT, and EXE.
#
# The app must run in the foreground — backgrounding a GUI app trips
# SIGTTOU/HUP and freezes the window. So the watcher goes to the background
# instead, and the trap kills it on exit so it doesn't keep rebuilding.
set -euo pipefail

watchexec --watch source --exts odin --debounce 200ms -- mise run build-app &
watcher=$!

# kill watcher; remove numbered DLL copies left behind by unclean exits
trap 'kill $watcher 2>/dev/null; rm -f "$HR_OUT"/${APP_NAME}_[0-9]*$DLL_EXT' EXIT INT TERM

# run from $HR_OUT (subshell) so the host finds the app dll + resources/ by relative path
(cd "$HR_OUT" && ./"$EXE")
