# Shared fixtures: a throwaway HOME holding a fake Claude Code project
# directory, so collect.py resolves transcripts without touching the real
# ~/.claude.

REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
COLLECT="$REPO_ROOT/scripts/collect.py"
SHELF="$REPO_ROOT/scripts/shelf.sh"
PORTABLE="$REPO_ROOT/scripts/portable.sh"

setup_fake_home() {
  export HOME="$BATS_TEST_TMPDIR/home"
  WORK_DIR="$BATS_TEST_TMPDIR/work/my-repo"
  mkdir -p "$WORK_DIR"
  WORK_DIR="$(cd "$WORK_DIR" && pwd -P)"
  PROJECT_DIR="$HOME/.claude/projects/$(printf '%s' "$WORK_DIR" | sed 's/[^A-Za-z0-9]/-/g')"
  mkdir -p "$PROJECT_DIR"
}

# send_record <caption> <path>...: one assistant line calling SendUserFile.
send_record() {
  local caption="$1"
  shift
  python3 - "$caption" "$@" <<'PY'
import json, sys
print(json.dumps({"type": "assistant", "message": {"content": [
    {"type": "tool_use", "name": "SendUserFile",
     "input": {"files": sys.argv[2:], "caption": sys.argv[1]}}]}}))
PY
}

# tool_record <name> <path>: a tool call that touches a file but does not
# deliver it.
tool_record() {
  printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"%s","input":{"file_path":"%s"}}]}}\n' "$1" "$2"
}

title_record() {
  printf '{"type":"custom-title","customTitle":"%s"}\n' "$1"
}

# age <file> <seconds>: push mtime into the past so recency order is fixed.
# GNU date formats an epoch with `-d @N`; BSD date (macOS) uses `-r N`, which
# GNU reads as "mtime of the file named N". Probe for GNU with a known answer
# rather than trying `-r` first, which could hit a stray file named N.
age() {
  local epoch=$(($(date +%s) - $2)) stamp
  if [ "$(date -u -d @0 +%Y 2>/dev/null)" = 1970 ]; then
    stamp="$(date -d "@$epoch" +%Y%m%d%H%M.%S)"
  else
    stamp="$(date -r "$epoch" +%Y%m%d%H%M.%S)"
  fi
  touch -t "$stamp" "$1"
}
