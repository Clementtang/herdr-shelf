#!/usr/bin/env bats
# scripts/portable.sh: the same answers from BSD tools (macOS) and GNU tools
# (Linux). The host's own tools cover one side; PATH stubs stand in for the
# other.

load test_helper

setup() {
  STUB_DIR="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUB_DIR"
  TARGET="$BATS_TEST_TMPDIR/transcript.jsonl"
  : >"$TARGET"
}

@test "should print only the mtime as one integer when stat is the host's own" {
  touch -t 202601020304.05 "$TARGET"
  expected="$(python3 -c 'import os, sys; print(int(os.stat(sys.argv[1]).st_mtime))' "$TARGET")"

  run bash -c '. "$1"; file_mtime "$2"' _ "$PORTABLE" "$TARGET"
  [ "$status" -eq 0 ]
  [ "${#lines[@]}" -eq 1 ]
  [[ "$output" =~ ^[0-9]+$ ]]
  [ "$output" = "$expected" ]
}

@test "should fall back to BSD stat -f %m when stat rejects -c" {
  cat >"$STUB_DIR/stat" <<'STUB'
#!/bin/bash
case "$1" in
  -c) echo "stat: illegal option -- c" >&2; exit 1 ;;
  -f) [ "$2" = "%m" ] && echo 1790000000 ;;
esac
STUB
  chmod +x "$STUB_DIR/stat"

  run env PATH="$STUB_DIR:$PATH" bash -c '. "$1"; file_mtime "$2"' _ "$PORTABLE" "$TARGET"
  [ "$status" -eq 0 ]
  [ "$output" = "1790000000" ]
}

@test "should fail with no output when the file does not exist" {
  run bash -c '. "$1"; file_mtime "$2"' _ "$PORTABLE" "$BATS_TEST_TMPDIR/missing"
  [ "$status" -ne 0 ]
  [ -z "$output" ]
}

@test "should default to /usr/bin/open on macOS" {
  printf '#!/bin/sh\necho Darwin\n' >"$STUB_DIR/uname"
  chmod +x "$STUB_DIR/uname"

  run env PATH="$STUB_DIR:$PATH" bash -c '. "$1"; default_opener' _ "$PORTABLE"
  [ "$output" = "/usr/bin/open" ]
}

@test "should default to xdg-open rather than open on Linux" {
  printf '#!/bin/sh\necho Linux\n' >"$STUB_DIR/uname"
  printf '#!/bin/sh\nexit 0\n' >"$STUB_DIR/xdg-open"
  printf '#!/bin/sh\nexit 0\n' >"$STUB_DIR/open"
  chmod +x "$STUB_DIR/uname" "$STUB_DIR/xdg-open" "$STUB_DIR/open"

  run env PATH="$STUB_DIR:$PATH" bash -c '. "$1"; default_opener' _ "$PORTABLE"
  [ "$output" = "$STUB_DIR/xdg-open" ]
}

@test "should push a file's mtime into the past when aged" {
  now="$(date +%s)"
  age "$TARGET" 600

  mtime="$(bash -c '. "$1"; file_mtime "$2"' _ "$PORTABLE" "$TARGET")"
  [ "$mtime" -ge $((now - 602)) ]
  [ "$mtime" -le $((now - 598)) ]
}
