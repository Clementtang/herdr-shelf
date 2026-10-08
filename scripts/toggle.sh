#!/usr/bin/env bash
# Action `shelf`: open the shelf beside the focused pane, or close it when
# the tab already has one. Pressing the key twice must never stack a second
# sidebar: a narrow shelf cannot show its own "q close" hint, so the key
# that opened it is the one people reach for to get rid of it.
#
# Shelf panes include the empty shells a herdr restart leaves behind (see
# shelf-panes.sh): closing those here keeps one press from stacking a fresh
# shelf beside a dead one.
set -u

herdr_bin="${HERDR_BIN_PATH:-herdr}"
plugin_root="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)}"
# shellcheck source=scripts/shelf-panes.sh
. "$plugin_root/scripts/shelf-panes.sh"

focused="$(printf '%s' "${HERDR_PLUGIN_CONTEXT_JSON:-}" | jq -r '.focused_pane_id // empty' 2>/dev/null)"
panes_json="$("$herdr_bin" pane list 2>/dev/null)"
tab="$(printf '%s' "$panes_json" \
  | jq -r --arg id "$focused" '.result.panes[] | select(.pane_id == $id) | .tab_id // empty' 2>/dev/null)"

closed=0
if [ -n "$tab" ]; then
  for pane in $(shelf_panes "$panes_json" "$tab"); do
    "$herdr_bin" pane close "$pane" >/dev/null 2>&1 && closed=1
  done
fi
[ "$closed" = 1 ] && exit 0

exec "$herdr_bin" plugin pane open --plugin "${HERDR_PLUGIN_ID:-clementtang.herdr-shelf}" \
  --entrypoint shelf --placement split --direction right --focus
