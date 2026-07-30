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

# run from $HR_OUT (subshell) so the host finds the app dll + resources/ by relative path.
#
# `mise run dev:debug` sets LLDB=1 to run under the debugger: a bare SIGSEGV is
# reaped by the kernel and all bash can report is "Segmentation fault: 11" — no
# file, no line, no stack. lldb catches the signal and prints a symbolized
# backtrace from the -debug builds instead.
(
  cd "$HR_OUT"
  if [ -n "${LLDB:-}" ]; then
    command -v lldb >/dev/null || { echo "LLDB=1 but lldb not found (xcode-select --install)" >&2; exit 1; }
    lldb --batch -o run -k 'bt all' -k quit -- ./"$EXE"
  else
    ./"$EXE"
  fi
)
