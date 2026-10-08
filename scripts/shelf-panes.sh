# shellcheck shell=bash
# Recognising shelf panes, sourced by toggle.sh and startup.sh.
# Expects herdr_bin and plugin_root to be set. bash 3.2 throughout.
#
# A live shelf runs scripts/shelf.sh. After a herdr restart the layout comes
# back but a plugin pane's command does not: the pane returns as a plain shell
# in the plugin root, still labelled with the manifest's pane title. Those
# orphans are recognised by label plus cwd; the label alone could belong to
# another plugin's "Files" pane.

# The [[panes]] title in herdr-plugin.toml, which herdr keeps as the label.
shelf_label="Files"

# runs_shelf <pane-id>: the pane's foreground process is this plugin's shelf.sh.
runs_shelf() {
  "$herdr_bin" pane process-info --pane "$1" 2>/dev/null \
    | jq -e --arg script "$plugin_root/scripts/shelf.sh" \
      '[.result.process_info.foreground_processes[]?.argv[]?] | index($script)' >/dev/null 2>&1
}

# shelf_panes <pane-list-json> [tab-id]: ids of panes that are a shelf, live or
# orphaned, optionally limited to one tab.
shelf_panes() {
  local pane
  for pane in $(printf '%s' "$1" | jq -r --arg tab "${2:-}" '.result.panes[]
      | select($tab == "" or .tab_id == $tab) | .pane_id' 2>/dev/null); do
    if is_labelled_shelf "$1" "$pane" || runs_shelf "$pane"; then
      printf '%s\n' "$pane"
    fi
  done
}

# orphan_shelves <pane-list-json>: ids of shelf panes whose shelf.sh is gone.
orphan_shelves() {
  local pane
  for pane in $(printf '%s' "$1" | jq -r '.result.panes[].pane_id' 2>/dev/null); do
    if is_labelled_shelf "$1" "$pane" && ! runs_shelf "$pane"; then
      printf '%s\n' "$pane"
    fi
  done
}

# is_labelled_shelf <pane-list-json> <pane-id>: label and cwd both match.
is_labelled_shelf() {
  printf '%s' "$1" | jq -e --arg id "$2" --arg label "$shelf_label" --arg root "$plugin_root" \
    '.result.panes[] | select(.pane_id == $id and .label == $label and .cwd == $root)' \
    >/dev/null 2>&1
}
