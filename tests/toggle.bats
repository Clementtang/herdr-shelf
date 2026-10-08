#!/usr/bin/env bats
# toggle.sh and startup.sh against a stub herdr: tab wK:t1 holds the focused
# pane wK:p1. FAKE_SHELVES names the panes whose foreground process is
# shelf.sh; FAKE_LABELLED the panes labelled "Files" in the plugin root (a
# live shelf, or the empty shell a herdr restart leaves); FAKE_FOREIGN the
# panes labelled "Files" somewhere else, as another plugin's pane would be.

load test_helper

TOGGLE="$REPO_ROOT/scripts/toggle.sh"
STARTUP="$REPO_ROOT/scripts/startup.sh"

setup() {
  STUB_DIR="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUB_DIR"
  export HERDR_CALLS="$BATS_TEST_TMPDIR/herdr-calls.log"
  : >"$HERDR_CALLS"
  export HERDR_PLUGIN_ROOT="$REPO_ROOT"
  export HERDR_PLUGIN_ID="clementtang.herdr-shelf"
  export HERDR_PLUGIN_CONTEXT_JSON='{"focused_pane_id":"wK:p1"}'
  export FAKE_SHELVES="" FAKE_LABELLED="" FAKE_FOREIGN=""
  cat >"$STUB_DIR/herdr" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >>"$HERDR_CALLS"
case "$1 $2" in
  "pane list")
    rows=""
    for pane in wK:p1:wK:t1 wK:p8:wK:t1 wK:p9:wK:t1 w6:p8:w6:t1; do
      id="${pane%:*:*}"; tab="${pane#*:*:}"
      extra=""
      case " $FAKE_LABELLED " in *" $id "*) extra=",\"label\":\"Files\",\"cwd\":\"$HERDR_PLUGIN_ROOT\"" ;; esac
      case " $FAKE_FOREIGN " in *" $id "*) extra=",\"label\":\"Files\",\"cwd\":\"/elsewhere\"" ;; esac
      rows="$rows${rows:+,}{\"pane_id\":\"$id\",\"tab_id\":\"$tab\"$extra}"
    done
    printf '{"result":{"panes":[%s]}}' "$rows"
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
  ! grep -q '^pane close' "$HERDR_CALLS" || false
}

@test "should close the shelf instead of opening another when the tab already has one" {
  FAKE_SHELVES="wK:p8" run bash "$TOGGLE"
  [ "$status" -eq 0 ]
  grep -qx 'pane close wK:p8' "$HERDR_CALLS"
  ! grep -q '^plugin pane open' "$HERDR_CALLS" || false
}

@test "should close every stacked shelf in the tab when more than one is open" {
  FAKE_SHELVES="wK:p8 wK:p9" run bash "$TOGGLE"
  grep -qx 'pane close wK:p8' "$HERDR_CALLS"
  grep -qx 'pane close wK:p9' "$HERDR_CALLS"
}

@test "should leave shelves in other tabs alone when toggling" {
  FAKE_SHELVES="wK:p8 w6:p8" run bash "$TOGGLE"
  grep -qx 'pane close wK:p8' "$HERDR_CALLS"
  ! grep -qx 'pane close w6:p8' "$HERDR_CALLS" || false
}

@test "should close an orphaned shelf instead of stacking a new one beside it" {
  FAKE_LABELLED="wK:p8" run bash "$TOGGLE"
  [ "$status" -eq 0 ]
  grep -qx 'pane close wK:p8' "$HERDR_CALLS"
  ! grep -q '^plugin pane open' "$HERDR_CALLS" || false
}

@test "should not treat another plugin's Files pane as a shelf" {
  FAKE_FOREIGN="wK:p8" run bash "$TOGGLE"
  ! grep -q '^pane close' "$HERDR_CALLS" || false
  grep -q '^plugin pane open' "$HERDR_CALLS"
}

@test "should close orphaned shelves in every tab on startup and keep live ones" {
  export HERDR_CONFIG_PATH="$BATS_TEST_TMPDIR/config.toml"
  # wK:p9 is a live shelf (labelled and running shelf.sh); wK:p8 and w6:p8
  # are shells a restart left behind; wK:p1 is an ordinary pane.
  FAKE_LABELLED="wK:p8 wK:p9 w6:p8" FAKE_SHELVES="wK:p9" HERDR_PLUGIN_EVENT=startup run bash "$STARTUP"
  [ "$status" -eq 0 ]
  grep -qx 'pane close wK:p8' "$HERDR_CALLS"
  grep -qx 'pane close w6:p8' "$HERDR_CALLS"
  ! grep -qx 'pane close wK:p9' "$HERDR_CALLS" || false
  ! grep -qx 'pane close wK:p1' "$HERDR_CALLS" || false
}

@test "should still bind prefix+f on startup after closing orphans" {
  export HERDR_CONFIG_PATH="$BATS_TEST_TMPDIR/config.toml"
  FAKE_LABELLED="wK:p8" HERDR_PLUGIN_EVENT=startup run bash "$STARTUP"
  [ "$status" -eq 0 ]
  grep -q 'command = "clementtang.herdr-shelf.shelf"' "$HERDR_CONFIG_PATH"
}
