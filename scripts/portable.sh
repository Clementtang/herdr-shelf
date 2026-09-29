# shellcheck shell=bash
# Portable helpers sourced by shelf.sh. macOS ships BSD stat and `open`,
# Linux ships GNU coreutils and xdg-open; the manifest declares both.
# bash 3.2 throughout, like the scripts that source this.

# file_mtime <path>: modification time in epoch seconds, and nothing else.
# GNU spelling first: GNU `stat -f` means "filesystem status" and exits 0,
# so trying the BSD spelling first would print free-block and inode counts
# on Linux and never reach the fallback. BSD stat rejects -c outright, so
# macOS falls through to `-f %m`.
file_mtime() {
  local mtime
  mtime="$(stat -c %Y "$1" 2>/dev/null)" || mtime="$(stat -f %m "$1" 2>/dev/null)" || return 1
  case "$mtime" in '' | *[!0-9]*) return 1 ;; esac
  printf '%s\n' "$mtime"
}

# default_opener: the platform's "open with the default app" command, used
# when SHELF_OPEN_CMD is missing. On Linux call xdg-open by name: `open` on
# a minimal Debian can be openvt, which would try to start a new VT.
default_opener() {
  case "$(uname -s 2>/dev/null)" in
    Darwin) printf '%s\n' /usr/bin/open ;;
    *) command -v xdg-open 2>/dev/null || printf '%s\n' xdg-open ;;
  esac
}
