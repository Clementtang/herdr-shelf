#!/usr/bin/env bash
# Startup hook: runs once after herdr restores the session.
#
# 1. Close orphaned shelves. A restore brings plugin panes back as plain
#    shells; the pane each shelf followed is not recorded anywhere, so it
#    cannot be restarted, and an empty "Files" pane only gets in the way.
# 2. Bind prefix+f (install-keybind.sh, silent when already bound).
set -u

herdr_bin="${HERDR_BIN_PATH:-herdr}"
plugin_root="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)}"
# shellcheck source=scripts/shelf-panes.sh
. "$plugin_root/scripts/shelf-panes.sh"

for pane in $(orphan_shelves "$("$herdr_bin" pane list 2>/dev/null)"); do
  "$herdr_bin" pane close "$pane" >/dev/null 2>&1
done

exec bash "$plugin_root/scripts/install-keybind.sh"
