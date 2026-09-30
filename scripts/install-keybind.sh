#!/usr/bin/env bash
# Action `install-keybind` and the startup hook: bind prefix+f to the shelf in
# config.toml so `herdr plugin install` is the only step, then reload.
#
# Leaves the config alone when the shelf is already bound (any key: a user
# who moved it keeps their choice) or when prefix+f belongs to something
# else. Silent on startup unless it changes something or needs the user.
#
# bash 3.2, like every script in this plugin.
set -u

herdr_bin="${HERDR_BIN_PATH:-herdr}"
config="${HERDR_CONFIG_PATH:-${XDG_CONFIG_HOME:-$HOME/.config}/herdr/config.toml}"
action="clementtang.herdr-shelf.shelf"
key="prefix+f"
on_startup=0
[ "${HERDR_PLUGIN_EVENT:-}" = "startup" ] && on_startup=1

notify() {
  "$herdr_bin" notification show "herdr-shelf" --body "$1" >/dev/null 2>&1
}

# has_setting <name> <value>: an uncommented `name = "value"` line exists.
# The value is escaped first: the `+` in prefix+f and the dots in the action
# id are regex operators, and unescaped `prefix+f` never matches itself.
has_setting() {
  local value
  value="$(printf '%s' "$2" | sed 's/[][\.*^$+?(){}|/]/\\&/g')"
  grep -Eq "^[[:space:]]*$1[[:space:]]*=[[:space:]]*\"$value\"" "$config" 2>/dev/null
}

if has_setting command "$action"; then
  [ "$on_startup" = 1 ] || notify "already bound, nothing to do"
  exit 0
fi

if has_setting key "$key"; then
  notify "$key is taken: bind $action to another key in $config"
  exit 1
fi

mkdir -p "$(dirname "$config")" || exit 1
cat >>"$config" <<EOF

# herdr-shelf: standing sidebar of the files this Claude session delivered
[[keys.command]]
key = "$key"
type = "plugin_action"
command = "$action"
EOF

if "$herdr_bin" server reload-config >/dev/null 2>&1; then
  notify "bound $key: press it again to close the shelf"
else
  notify "bound $key in $config, but reload failed: run herdr server reload-config"
  exit 1
fi
