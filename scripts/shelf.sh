#!/usr/bin/env bash
# Pane `shelf`: a standing list of every file the neighbouring Claude Code
# session has delivered, newest first, opened with the user's own router.
#
# Bound to ONE pane, not to the project: a project directory holds every
# session ever run there and several are usually live at once, so the shelf
# follows the origin pane's title (the session's /rename name) and matches it
# against the transcript's customTitle. See scripts/collect.py.
#
# bash 3.2 (macOS /bin/bash, which herdr runs `bash` as) throughout: no
# associative arrays, no `${var,,}`, and `read -t` takes whole seconds only.
set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
herdr_bin="${HERDR_BIN_PATH:-herdr}"
open_cmd="${SHELF_OPEN_CMD:-$HOME/.local/bin/semantic-open}"
[ -x "$open_cmd" ] || open_cmd="/usr/bin/open"
poll_seconds="${SHELF_POLL_SECONDS:-2}"

# Origin pane: the plugin context names the pane that was focused when the
# shelf opened. That binding is deliberate - the shelf keeps showing that
# session even while the user works in another pane of the same tab.
origin_pane="${SHELF_ORIGIN_PANE:-}"
if [ -z "$origin_pane" ] && [ -n "${HERDR_PLUGIN_CONTEXT_JSON:-}" ]; then
  origin_pane="$(printf '%s' "$HERDR_PLUGIN_CONTEXT_JSON" | jq -r '.focused_pane_id // empty' 2>/dev/null)"
fi

tty_in=/dev/tty
{ : <"$tty_in"; } 2>/dev/null || tty_in=/dev/stdin

RESET=$'\033[0m'
DIM=$'\033[2;90m'
SEL=$'\033[0;1;30;48;5;179m'
HEAD=$'\033[0;1;38;5;179m'
CAP=$'\033[0;38;5;245m'
CLR_HOME=$'\033[H'
CLR_EOD=$'\033[J'
CLR_EOL=$'\033[K'
CURSOR_HIDE=$'\033[?25l'
CURSOR_SHOW=$'\033[?25h'

cleanup() {
  printf '%s%s' "$CURSOR_SHOW" "$RESET"
}
trap cleanup EXIT

# pane_field <pane-id> <jq-path> -> that field of the pane, empty on failure.
pane_field() {
  "$herdr_bin" pane list 2>/dev/null \
    | jq -r --arg id "$1" ".result.panes[] | select(.pane_id == \$id) | $2 // empty" 2>/dev/null
}

# session_title: the origin pane's terminal title with herdr's leading status
# glyph and padding removed, which is exactly the session's /rename name.
session_title() {
  local raw
  raw="$(pane_field "$origin_pane" '.terminal_title')"
  printf '%s' "$raw" | sed 's/^[^A-Za-z0-9_~./-]*//; s/[[:space:]]*$//'
}

paths=()
captions=()
transcript=""
title=""
cwd=""

load() {
  local line first=1
  title="$(session_title)"
  cwd="$(pane_field "$origin_pane" '.cwd')"
  [ -n "$cwd" ] || cwd="$PWD"
  paths=()
  captions=()
  transcript=""
  while IFS=$'\t' read -r left right; do
    if [ "$first" = 1 ] && [ "$left" = "#transcript" ]; then
      transcript="$right"
      first=0
      continue
    fi
    first=0
    [ -n "$left" ] || continue
    paths[${#paths[@]}]="$left"
    captions[${#captions[@]}]="$right"
  done < <(python3 "$script_dir/collect.py" "$cwd" "$title" 2>/dev/null)
}

# icon <path>: one glyph per kind, so the list scans as fast as a Finder
# column does.
icon() {
  local ext
  ext="$(printf '%s' "${1##*.}" | tr '[:upper:]' '[:lower:]')"
  case "$ext" in
    m4a | mp3 | wav | aac | flac | aiff) printf '\xe2\x99\xaa' ;;
    mp4 | mov | m4v | webm) printf '\xe2\x96\xb6' ;;
    png | jpg | jpeg | gif | webp | heic | svg) printf '\xe2\x96\xa3' ;;
    pdf) printf '\xe2\x96\xa4' ;;
    md | markdown | txt) printf '\xe2\x96\xa5' ;;
    *) printf '\xe2\x97\x86' ;;
  esac
}

cols() {
  local size
  size="$(stty size <"$tty_in" 2>/dev/null | awk '{print $2}')"
  case "$size" in '' | *[!0-9]*) printf '40' ;; *) printf '%s' "$size" ;; esac
}

rows() {
  local size
  size="$(stty size <"$tty_in" 2>/dev/null | awk '{print $1}')"
  case "$size" in '' | *[!0-9]*) printf '24' ;; *) printf '%s' "$size" ;; esac
}

# fit <text> <width>: truncate to width columns, ellipsis on the LEFT so the
# filename (the part that differs) always survives.
fit() {
  local text="$1" width="$2"
  [ "$width" -lt 4 ] && width=4
  if [ "${#text}" -le "$width" ]; then
    printf '%s' "$text"
  else
    printf '\xe2\x80\xa6%s' "${text:$((${#text} - width + 1))}"
  fi
}

# fit_end <text> <width>: truncate to width columns with the ellipsis on the
# RIGHT, for lines whose beginning carries the meaning (the header, captions).
fit_end() {
  local text="$1" width="$2"
  [ "$width" -lt 4 ] && width=4
  if [ "${#text}" -le "$width" ]; then
    printf '%s' "$text"
  else
    printf '%s\xe2\x80\xa6' "${text:0:$((width - 1))}"
  fi
}

selected=0
top=0

draw() {
  local width height list_height i frame line name

  width="$(cols)"
  height="$(rows)"
  # 2 header rows + 1 caption footer.
  list_height=$((height - 3))
  [ "$list_height" -lt 1 ] && list_height=1

  [ "$selected" -ge "${#paths[@]}" ] && selected=$((${#paths[@]} - 1))
  [ "$selected" -lt 0 ] && selected=0
  [ "$selected" -lt "$top" ] && top="$selected"
  [ "$selected" -ge $((top + list_height)) ] && top=$((selected - list_height + 1))
  [ "$top" -lt 0 ] && top=0

  frame="${CLR_HOME}${HEAD}$(fit_end "FILES  ${title:-session}" "$width")${RESET}${CLR_EOL}"$'\n'
  frame+="${DIM}$(fit_end "${#paths[@]} file(s) · enter open · r reload · q close" "$width")${RESET}${CLR_EOL}"$'\n'

  i="$top"
  while [ "$i" -lt "${#paths[@]}" ] && [ "$i" -lt $((top + list_height)) ]; do
    name="${paths[$i]##*/}"
    line=" $(icon "${paths[$i]}") $(fit "$name" $((width - 4)))"
    if [ "$i" -eq "$selected" ]; then
      frame+="${SEL}${line}${RESET}${CLR_EOL}"$'\n'
    else
      frame+="${line}${CLR_EOL}"$'\n'
    fi
    i=$((i + 1))
  done

  if [ "${#paths[@]}" -eq 0 ]; then
    frame+="${DIM}$(fit "nothing delivered yet" "$width")${RESET}${CLR_EOL}"$'\n'
  fi

  # Caption of the selection, pinned to the bottom: the rows above stay one
  # line each, so the list height never depends on where the cursor is.
  frame+="${CLR_EOD}"
  frame+=$'\n'"${CAP}$(fit_end "${captions[$selected]:-}" "$width")${RESET}${CLR_EOL}"
  printf '%s%s' "$CURSOR_HIDE" "$frame"
}

open_selected() {
  local path="${paths[$selected]:-}"
  [ -n "$path" ] || return 0
  [ -e "$path" ] || return 0
  # Detached: herdr kills a pane's process group when the pane closes, and a
  # Quick Look window started from here must outlive that.
  if command -v perl >/dev/null 2>&1; then
    perl -MPOSIX -e '
      my $pid = fork // die "fork: $!";
      if ($pid) { waitpid($pid, 0); exit($? >> 8) }
      POSIX::setsid() or die "setsid: $!";
      my $grandchild = fork // die "fork: $!";
      exit 0 if $grandchild;
      exec @ARGV or die "exec $ARGV[0]: $!";
    ' "$open_cmd" "$path" >/dev/null 2>&1 </dev/null
  else
    nohup "$open_cmd" "$path" >/dev/null 2>&1 </dev/null &
  fi
}

stamp() {
  [ -n "$transcript" ] && [ -f "$transcript" ] || return 0
  stat -f %m "$transcript" 2>/dev/null || stat -c %Y "$transcript" 2>/dev/null
}

load
draw
last_stamp="$(stamp)"

while :; do
  # Whole-second timeout: bash 3.2 rejects a fractional one outright, which
  # would spin this loop instead of pacing it.
  if IFS= read -rsn1 -t "$poll_seconds" key <"$tty_in" 2>/dev/null; then
    case "$key" in
      q | Q) break ;;
      j | J) selected=$((selected + 1)); draw ;;
      k | K) selected=$((selected - 1)); draw ;;
      r | R) load; draw; last_stamp="$(stamp)" ;;
      '') open_selected ;;
      $'\e')
        # Arrow keys arrive as ESC [ A/B; a bare Esc is left alone so it never
        # closes a standing pane by accident.
        IFS= read -rsn1 -t 1 c1 <"$tty_in" 2>/dev/null || continue
        [ "$c1" = "[" ] || continue
        IFS= read -rsn1 -t 1 c2 <"$tty_in" 2>/dev/null || continue
        case "$c2" in
          A) selected=$((selected - 1)); draw ;;
          B) selected=$((selected + 1)); draw ;;
        esac
        ;;
    esac
    continue
  fi
  current="$(stamp)"
  if [ "$current" != "$last_stamp" ]; then
    load
    draw
    last_stamp="$current"
  fi
done

cleanup
