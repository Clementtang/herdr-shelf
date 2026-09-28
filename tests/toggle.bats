#!/usr/bin/env bats
# toggle.sh against a stub herdr: tab wK:t1 holds the focused pane wK:p1, and
# FAKE_SHELVES names the panes whose foreground process is shelf.sh.

load test_helper

TOGGLE="$REPO_ROOT/scripts/toggle.sh"

setup() {
  STUB_DIR="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUB_DIR"
  export HERDR_CALLS="$BATS_TEST_TMPDIR/herdr-calls.log"
  : >"$HERDR_CALLS"
  export HERDR_PLUGIN_ROOT="$REPO_ROOT"
  export HERDR_PLUGIN_ID="clementtang.herdr-shelf"
  export HERDR_PLUGIN_CONTEXT_JSON='{"focused_pane_id":"wK:p1"}'
  export FAKE_SHELVES=""
  cat >"$STUB_DIR/herdr" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$HERDR_CALLS"
case "$1 $2" in
  "pane list")
    printf '{"result":{"panes":[{"pane_id":"wK:p1","tab_id":"wK:t1"},{"pane_id":"wK:p8","tab_id":"wK:t1"},{"pane_id":"wK:p9","tab_id":"wK:t1"},{"pane_id":"w6:p8","tab_id":"w6:t1"}]}}'
    ;;
  "pane process-info")
    argv='"zsh"'
    case " $FAKE_SHELVES " in
      *" $4 "*) argv="\"bash\",\"$HERDR_PLUGIN_ROOT/scripts/shelf.sh\"" ;;
    esac
    printf '{"result":{"process_info":{"foreground_processes":[{"argv":[%s]}]}}}' "$argv"
    ;;
esac
STUB
  chmod +x "$STUB_DIR/herdr"
  export HERDR_BIN_PATH="$STUB_DIR/herdr"
}

@test "should open a shelf when the focused tab has none" {
  FAKE_SHELVES="w6:p8" run bash "$TOGGLE"
  [ "$status" -eq 0 ]
  grep -q '^plugin pane open --plugin clementtang.herdr-shelf --entrypoint shelf' "$HERDR_CALLS"
  ! grep -q '^pane close' "$HERDR_CALLS"
}

@test "should close the shelf instead of opening another when the tab already has one" {
  FAKE_SHELVES="wK:p8" run bash "$TOGGLE"
  [ "$status" -eq 0 ]
  grep -qx 'pane close wK:p8' "$HERDR_CALLS"
  ! grep -q '^plugin pane open' "$HERDR_CALLS"
}

@test "should close every stacked shelf in the tab when more than one is open" {
  FAKE_SHELVES="wK:p8 wK:p9" run bash "$TOGGLE"
  grep -qx 'pane close wK:p8' "$HERDR_CALLS"
  grep -qx 'pane close wK:p9' "$HERDR_CALLS"
}

@test "should leave shelves in other tabs alone when toggling" {
  FAKE_SHELVES="wK:p8 w6:p8" run bash "$TOGGLE"
  grep -qx 'pane close wK:p8' "$HERDR_CALLS"
  ! grep -qx 'pane close w6:p8' "$HERDR_CALLS"
}
