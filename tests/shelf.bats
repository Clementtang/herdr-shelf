#!/usr/bin/env bats
# Drives shelf.sh headless: keys arrive on stdin (SHELF_TTY), herdr is a stub
# that knows one pane, and the open command appends its argument to a log.

load test_helper

setup() {
  setup_fake_home
  CLIP_DIR="$BATS_TEST_TMPDIR/samples/2026-09-21"
  mkdir -p "$CLIP_DIR"
  touch "$CLIP_DIR/SPEAKER_00.m4a" "$CLIP_DIR/SPEAKER_01.m4a"
  {
    title_record my-session
    send_record "speaker zero" "$CLIP_DIR/SPEAKER_00.m4a"
    send_record "speaker one" "$CLIP_DIR/SPEAKER_01.m4a"
  } >"$PROJECT_DIR/s1.jsonl"

  SESSION_FILE="$BATS_TEST_TMPDIR/session-id"
  : >"$SESSION_FILE"
  STUB_DIR="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUB_DIR"
  OPEN_LOG="$BATS_TEST_TMPDIR/opened.log"
  : >"$OPEN_LOG"
  cat >"$STUB_DIR/herdr" <<STUB
#!/bin/bash
if [ "\$1 \$2" = "pane list" ]; then
  printf '{"result":{"panes":[{"pane_id":"w1:p1","terminal_title":"\xe2\x9c\xb3 my-session","cwd":"%s","agent_session":{"value":"%s"}}]}}' "$WORK_DIR" "\$(cat "$SESSION_FILE" 2>/dev/null)"
fi
STUB
  printf '#!/bin/bash\nprintf "%%s\\n" "$1" >>"%s"\n' "$OPEN_LOG" >"$STUB_DIR/open"
  chmod +x "$STUB_DIR/herdr" "$STUB_DIR/open"

  export HERDR_BIN_PATH="$STUB_DIR/herdr"
  export SHELF_OPEN_CMD="$STUB_DIR/open"
  export SHELF_ORIGIN_PANE="w1:p1"
  export SHELF_TTY=/dev/stdin
}

# run_keys <bytes>: feed keys to the shelf and capture the screen with the
# escape sequences stripped.
run_keys() {
  run bash -c 'printf "$1" | bash "$2" | sed "s/$(printf "\033")\[[0-9;?]*[A-Za-z]//g"' _ "$1" "$SHELF"
}

# opened: the open log once the detached opener has written, which happens
# after the shelf has already exited.
opened() {
  local tries=0
  while [ ! -s "$OPEN_LOG" ] && [ "$tries" -lt 20 ]; do
    sleep 0.1
    tries=$((tries + 1))
  done
  sleep 0.2
  cat "$OPEN_LOG"
}

@test "should show the session title, file names and parent folders when opened" {
  run_keys 'q'
  [ "$status" -eq 0 ]
  [[ "$output" == *"FILES  my-session"* ]]
  [[ "$output" == *"2 file(s)"* ]]
  [[ "$output" == *"SPEAKER_01.m4a"* ]]
  [[ "$output" == *"2026-09-21"* ]]
  [[ "$output" == *"speaker one"* ]]
}

@test "should put the close key first in the hint row when the pane is narrow" {
  run_keys 'q'
  [[ "$output" == *" q close"* ]]
}

@test "should open the newest file when Enter is pressed without moving" {
  run_keys '\nq'
  [ "$(opened)" = "$CLIP_DIR/SPEAKER_01.m4a" ]
}

@test "should open the second file when j then Enter is pressed" {
  run_keys 'j\nq'
  [ "$(opened)" = "$CLIP_DIR/SPEAKER_00.m4a" ]
}

@test "should open the same file when either of its two rows is clicked" {
  # Rows 1-2 are the header; the second entry owns rows 5 and 6.
  run_keys '\033[<0;5;5Mq'
  [ "$(opened)" = "$CLIP_DIR/SPEAKER_00.m4a" ]

  : >"$OPEN_LOG"
  run_keys '\033[<0;5;6Mq'
  [ "$(opened)" = "$CLIP_DIR/SPEAKER_00.m4a" ]
}

@test "should open once when a click sends both press and release" {
  run_keys '\033[<0;5;3M\033[<0;5;3mq'
  [ "$(opened)" = "$CLIP_DIR/SPEAKER_01.m4a" ]
}

@test "should not open anything when a click lands below the list" {
  run_keys '\033[<0;5;15Mq'
  sleep 0.5
  [ ! -s "$OPEN_LOG" ]
}

@test "should not call the opener when the delivered file no longer exists" {
  rm "$CLIP_DIR/SPEAKER_01.m4a"
  run_keys '\nq'
  sleep 0.5
  [ ! -s "$OPEN_LOG" ]
}

@test "should list the pane's own session when another session shares its title" {
  { title_record my-session; send_record "" "$CLIP_DIR/SPEAKER_00.m4a"; } >"$PROJECT_DIR/1234-abcd.jsonl"
  age "$PROJECT_DIR/1234-abcd.jsonl" 600
  printf '1234-abcd' >"$SESSION_FILE"

  run_keys 'q'
  [[ "$output" == *"1 file(s)"* ]]
}

@test "should switch to the new transcript when the pane's session id changes" {
  { title_record other; send_record "" "$CLIP_DIR/SPEAKER_00.m4a"; } >"$PROJECT_DIR/5678-efgh.jsonl"
  age "$PROJECT_DIR/5678-efgh.jsonl" 600
  age "$PROJECT_DIR/s1.jsonl" 900
  printf '5678-efgh' >"$SESSION_FILE"

  # s1 (two files) takes over mid-run, the way /clear hands the pane a new id.
  run bash -c '(sleep 1; printf s1 >"$1"; sleep 3; printf q) \
    | SHELF_POLL_SECONDS=1 bash "$2" | sed "s/$(printf "\033")\[[0-9;?]*[A-Za-z]//g"' _ "$SESSION_FILE" "$SHELF"
  [[ "$output" == *"1 file(s)"* ]]
  [[ "$output" == *"2 file(s)"* ]]
}
