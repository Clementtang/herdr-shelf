#!/usr/bin/env bash
# Action `shelf`: open the shelf beside the focused pane, or close it when
# the tab already has one. Pressing the key twice must never stack a second
# sidebar: a narrow shelf cannot show its own "q close" hint, so the key
# that opened it is the one people reach for to get rid of it.
#
# A shelf pane is recognised by its foreground process running this plugin's
# shelf.sh; herdr gives plugin panes no title or tag to match on.
set -u

herdr_bin="${HERDR_BIN_PATH:-herdr}"
plugin_root="${HERDR_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)}"
shelf_script="$plugin_root/scripts/shelf.sh"

focused="$(printf '%s' "${HERDR_PLUGIN_CONTEXT_JSON:-}" | jq -r '.focused_pane_id // empty' 2>/dev/null)"
panes_json="$("$herdr_bin" pane list 2>/dev/null)"
tab="$(printf '%s' "$panes_json" \
  | jq -r --arg id "$focused" '.result.panes[] | select(.pane_id == $id) | .tab_id // empty' 2>/dev/null)"

closed=0
if [ -n "$tab" ]; then
  for pane in $(printf '%s' "$panes_json" \
    | jq -r --arg tab "$tab" '.result.panes[] | select(.tab_id == $tab) | .pane_id' 2>/dev/null); do
    if "$herdr_bin" pane process-info --pane "$pane" 2>/dev/null \
      | jq -e --arg script "$shelf_script" \
        '[.result.process_info.foreground_processes[]?.argv[]?] | index($script)' >/dev/null 2>&1; then
      "$herdr_bin" pane close "$pane" >/dev/null 2>&1 && closed=1
    fi
  done
fi
[ "$closed" = 1 ] && exit 0

exec "$herdr_bin" plugin pane open --plugin "${HERDR_PLUGIN_ID:-clementtang.herdr-shelf}" \
  --entrypoint shelf --placement split --direction right --focus
