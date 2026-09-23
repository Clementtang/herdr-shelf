#!/usr/bin/env bats

load test_helper

setup() {
  setup_fake_home
}

@test "should list SendUserFile paths newest first with caption when transcript has deliveries" {
  {
    send_record "first batch" /clips/a.m4a
    send_record "second batch" /clips/b.m4a /clips/c.m4a
  } >"$PROJECT_DIR/s1.jsonl"

  run python3 "$COLLECT" "$WORK_DIR" ""
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "#transcript	$PROJECT_DIR/s1.jsonl" ]
  [ "${lines[1]}" = "/clips/c.m4a	second batch" ]
  [ "${lines[2]}" = "/clips/b.m4a	second batch" ]
  [ "${lines[3]}" = "/clips/a.m4a	first batch" ]
  [ "${#lines[@]}" -eq 4 ]
}

@test "should ignore files only read or written when no SendUserFile names them" {
  {
    tool_record Read /src/main.py
    tool_record Write /notes/out.md
    send_record "" /clips/a.m4a
  } >"$PROJECT_DIR/s1.jsonl"

  run python3 "$COLLECT" "$WORK_DIR" ""
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 2 ]
  [ "${lines[1]}" = "/clips/a.m4a	" ]
}

@test "should keep the newest position and caption when a path is sent twice" {
  {
    send_record "old" /clips/a.m4a
    send_record "middle" /clips/b.m4a
    send_record "resent" /clips/a.m4a
  } >"$PROJECT_DIR/s1.jsonl"

  run python3 "$COLLECT" "$WORK_DIR" ""
  [ "${lines[1]}" = "/clips/a.m4a	resent" ]
  [ "${lines[2]}" = "/clips/b.m4a	middle" ]
  [ "${#lines[@]}" -eq 3 ]
}

@test "should pick the transcript whose customTitle matches when several sessions share a project" {
  { title_record wanted; send_record "" /clips/mine.m4a; } >"$PROJECT_DIR/older.jsonl"
  { title_record other; send_record "" /clips/theirs.m4a; } >"$PROJECT_DIR/newer.jsonl"
  age "$PROJECT_DIR/older.jsonl" 600

  run python3 "$COLLECT" "$WORK_DIR" wanted
  [ "${lines[0]}" = "#transcript	$PROJECT_DIR/older.jsonl" ]
  [ "${lines[1]}" = "/clips/mine.m4a	" ]
}

@test "should match the last customTitle when a session was renamed mid-file" {
  {
    title_record first-name
    send_record "" /clips/a.m4a
    title_record renamed
  } >"$PROJECT_DIR/renamed.jsonl"
  { title_record first-name; } >"$PROJECT_DIR/impostor.jsonl"
  age "$PROJECT_DIR/renamed.jsonl" 600

  run python3 "$COLLECT" "$WORK_DIR" renamed
  [ "${lines[0]}" = "#transcript	$PROJECT_DIR/renamed.jsonl" ]

  run python3 "$COLLECT" "$WORK_DIR" first-name
  [ "${lines[0]}" = "#transcript	$PROJECT_DIR/impostor.jsonl" ]
}

@test "should fall back to the newest transcript when no title matches" {
  send_record "" /clips/old.m4a >"$PROJECT_DIR/old.jsonl"
  send_record "" /clips/new.m4a >"$PROJECT_DIR/new.jsonl"
  age "$PROJECT_DIR/old.jsonl" 600

  run python3 "$COLLECT" "$WORK_DIR" no-such-title
  [ "${lines[0]}" = "#transcript	$PROJECT_DIR/new.jsonl" ]

  run python3 "$COLLECT" "$WORK_DIR" ""
  [ "${lines[0]}" = "#transcript	$PROJECT_DIR/new.jsonl" ]
}

@test "should exit 1 with no output when the project has no transcripts" {
  run python3 "$COLLECT" "$BATS_TEST_TMPDIR/elsewhere" ""
  [ "$status" -eq 1 ]
  [ -z "$output" ]
}

@test "should skip malformed lines and flatten tabs in captions when parsing" {
  {
    printf 'not json at all\n'
    printf '{"message":{"content":"plain string"}}\n'
    send_record "col1	col2" /clips/a.m4a
  } >"$PROJECT_DIR/s1.jsonl"

  run python3 "$COLLECT" "$WORK_DIR" ""
  [ "$status" -eq 0 ]
  [ "${lines[1]}" = "/clips/a.m4a	col1 col2" ]
}
