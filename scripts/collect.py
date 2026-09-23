#!/usr/bin/env python3
"""Collect the files a Claude Code session delivered, newest first.

Reads the session transcript (~/.claude/projects/<mangled cwd>/<session>.jsonl)
and prints one row per file:

    <path>\t<caption>

Only SendUserFile tool calls count: those are the files the session actually
put in front of the user, which is what the shelf lists. A path repeated
across turns keeps its newest position, so re-sending a clip moves it to the
top instead of adding a second row.
"""

import json
import os
import sys


def project_dir(cwd):
    # Claude Code's own mangling: every character outside [A-Za-z0-9] in the
    # absolute path becomes a dash, so /Users/x/91app-map is stored as
    # -Users-x-91app-map.
    mangled = "".join(c if c.isalnum() else "-" for c in os.path.abspath(cwd))
    return os.path.join(os.path.expanduser("~/.claude/projects"), mangled)


def transcripts_by_recency(directory):
    try:
        entries = [
            os.path.join(directory, name)
            for name in os.listdir(directory)
            if name.endswith(".jsonl")
        ]
    except OSError:
        return []
    return sorted(entries, key=lambda p: os.path.getmtime(p), reverse=True)


def custom_title(transcript):
    """The session's current /rename title, or None.

    The title is written as its own record, and a later rename appends a new
    one, so the LAST record wins. The cheap substring test keeps this to a
    scan rather than a JSON parse per line: these files reach tens of MB.
    """
    title = None
    try:
        with open(transcript, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                if '"custom-title"' not in line:
                    continue
                try:
                    record = json.loads(line)
                except ValueError:
                    continue
                if record.get("type") == "custom-title":
                    title = record.get("customTitle") or title
    except OSError:
        return None
    return title


def resolve_transcript(directory, title):
    """The transcript for `title`, else the most recently written one.

    One project directory holds every session ever run in that repo, and the
    user keeps several live at once, so recency alone picks the wrong pane's
    session. herdr's pane title carries the session's /rename name, which is
    the only identifier both sides share.
    """
    candidates = transcripts_by_recency(directory)
    if title:
        for transcript in candidates[:40]:
            if custom_title(transcript) == title:
                return transcript
    return candidates[0] if candidates else None


def collect(transcript):
    """Return [(path, caption)], newest first, deduped by path."""
    found = {}
    order = []
    with open(transcript, encoding="utf-8", errors="replace") as handle:
        for line in handle:
            try:
                record = json.loads(line)
            except ValueError:
                continue
            content = (record.get("message") or {}).get("content")
            if not isinstance(content, list):
                continue
            for block in content:
                if not isinstance(block, dict):
                    continue
                if block.get("type") != "tool_use":
                    continue
                if block.get("name") != "SendUserFile":
                    continue
                params = block.get("input") or {}
                caption = params.get("caption") or ""
                for path in params.get("files") or []:
                    if not isinstance(path, str):
                        continue
                    if path not in found:
                        order.append(path)
                    found[path] = caption
    return [(path, found[path]) for path in reversed(order)]


def main():
    cwd = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    title = sys.argv[2] if len(sys.argv) > 2 else ""
    transcript = resolve_transcript(project_dir(cwd), title)
    if not transcript or not os.path.exists(transcript):
        return 1
    # The path is printed so the caller can watch the transcript's mtime
    # without repeating the newest-file search on every poll.
    sys.stdout.write("#transcript\t%s\n" % transcript)
    for path, caption in collect(transcript):
        sys.stdout.write("%s\t%s\n" % (path, caption.replace("\t", " ")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
