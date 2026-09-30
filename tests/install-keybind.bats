#!/usr/bin/env bats
# install-keybind.sh against a throwaway config.toml and a stub herdr that
# logs every call.

load test_helper

INSTALL="$REPO_ROOT/scripts/install-keybind.sh"

setup() {
  export HERDR_CONFIG_PATH="$BATS_TEST_TMPDIR/herdr/config.toml"
  export HERDR_CALLS="$BATS_TEST_TMPDIR/herdr-calls.log"
  : >"$HERDR_CALLS"
  STUB_DIR="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUB_DIR"
  cat >"$STUB_DIR/herdr" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$HERDR_CALLS"
[ "$1 $2" = "server reload-config" ] && [ -n "${FAIL_RELOAD:-}" ] && exit 1
exit 0
STUB
  chmod +x "$STUB_DIR/herdr"
  export HERDR_BIN_PATH="$STUB_DIR/herdr"
  unset HERDR_PLUGIN_EVENT
}

bindings() {
  grep -c 'command = "clementtang.herdr-shelf.shelf"' "$HERDR_CONFIG_PATH"
}

@test "should create the config with the binding and reload when none exists" {
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ "$(bindings)" -eq 1 ]
  grep -q '^key = "prefix+f"$' "$HERDR_CONFIG_PATH"
  grep -qx 'server reload-config' "$HERDR_CALLS"
}

@test "should keep existing settings when appending the binding" {
  mkdir -p "${HERDR_CONFIG_PATH%/*}"
  printf '[ui]\ntheme = "dark"\n' >"$HERDR_CONFIG_PATH"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ "$(head -2 "$HERDR_CONFIG_PATH")" = '[ui]
theme = "dark"' ]
  [ "$(bindings)" -eq 1 ]
}

@test "should add the binding only once when run repeatedly" {
  bash "$INSTALL"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ "$(bindings)" -eq 1 ]
}

@test "should leave the config alone when the shelf is bound to another key" {
  mkdir -p "${HERDR_CONFIG_PATH%/*}"
  printf '[[keys.command]]\nkey = "prefix+s"\ntype = "plugin_action"\ncommand = "clementtang.herdr-shelf.shelf"\n' >"$HERDR_CONFIG_PATH"
  before="$(cat "$HERDR_CONFIG_PATH")"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ "$(cat "$HERDR_CONFIG_PATH")" = "$before" ]
  ! grep -q 'reload-config' "$HERDR_CALLS"
}

@test "should refuse and notify when prefix+f belongs to another command" {
  mkdir -p "${HERDR_CONFIG_PATH%/*}"
  printf '[[keys.command]]\nkey = "prefix+f"\ntype = "plugin_action"\ncommand = "someone.else.find"\n' >"$HERDR_CONFIG_PATH"
  before="$(cat "$HERDR_CONFIG_PATH")"
  run bash "$INSTALL"
  [ "$status" -eq 1 ]
  [ "$(cat "$HERDR_CONFIG_PATH")" = "$before" ]
  grep -q '^notification show herdr-shelf --body prefix+f is taken' "$HERDR_CALLS"
}

@test "should not treat prefixf or a commented binding as prefix+f being taken" {
  # `+` is a regex operator: an unescaped pattern matched "prefixf" and
  # missed the literal "prefix+f".
  mkdir -p "${HERDR_CONFIG_PATH%/*}"
  printf 'key = "prefixf"\n# key = "prefix+f"\n' >"$HERDR_CONFIG_PATH"
  run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ "$(bindings)" -eq 1 ]
}

@test "should stay silent on startup when the shelf is already bound" {
  bash "$INSTALL"
  : >"$HERDR_CALLS"
  HERDR_PLUGIN_EVENT=startup run bash "$INSTALL"
  [ "$status" -eq 0 ]
  [ ! -s "$HERDR_CALLS" ]
}

@test "should exit 1 and say so when reload-config fails" {
  FAIL_RELOAD=1 run bash "$INSTALL"
  [ "$status" -eq 1 ]
  [ "$(bindings)" -eq 1 ]
  grep -q 'reload failed' "$HERDR_CALLS"
}
