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

import glob
import json
import os
import sys

PROJECTS_ROOT = os.path.expanduser("~/.claude/projects")


def project_dir(cwd):
    # Claude Code's own mangling: every character outside [A-Za-z0-9] in the
    # absolute path becomes a dash, so /Users/x/91app-map is stored as
    # -Users-x-91app-map.
    mangled = "".join(c if c.isalnum() else "-" for c in os.path.abspath(cwd))
    return os.path.join(PROJECTS_ROOT, mangled)


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


def transcript_for_session(directory, session_id):
    """The transcript named by herdr's session id, or None.

    Looked up under the pane's project directory first, then under every
    project: the directory is named after where claude started, and the
    pane's cwd can have moved since.
    """
    # The id becomes a filename; anything but a plain UUID-like token would
    # let a crafted value step outside the projects directory.
    if not session_id or not all(c.isalnum() or c == "-" for c in session_id):
        return None
    name = session_id + ".jsonl"
    direct = os.path.join(directory, name)
    if os.path.isfile(direct):
        return direct
    matches = glob.glob(os.path.join(PROJECTS_ROOT, "*", name))
    return matches[0] if matches else None


def resolve_transcript(directory, title, session_id=""):
    """The transcript for this pane's session.

    herdr reports the Claude session id of each pane, which names the
    transcript exactly. Without it (older herdr, or a pane herdr has not
    identified) the pane title is matched against the /rename name.

    Neither matching returns None rather than the newest transcript: one
    project directory holds every session ever run in that repo and several
    are usually live, so a recency guess shows another session's files as
    if they were this pane's.
    """
    exact = transcript_for_session(directory, session_id)
    if exact:
        return exact
    candidates = transcripts_by_recency(directory)
    if title:
        for transcript in candidates[:40]:
            if custom_title(transcript) == title:
                return transcript
    return None


def collect(transcript):
    """Return [(path, caption)], newest first, deduped by path.

    A call counts only if it delivered: `files` must be a list (a model can
    pass the list JSON-encoded as one string, which the tool rejects and
    which would otherwise be iterated character by character), and its
    tool_result must not be an error.
    """
    sends = []
    failed = set()
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
                if block.get("type") == "tool_result" and block.get("is_error"):
                    failed.add(block.get("tool_use_id"))
                    continue
                if block.get("type") != "tool_use":
                    continue
                if block.get("name") != "SendUserFile":
                    continue
                params = block.get("input") or {}
                files = params.get("files")
                if not isinstance(files, list):
                    continue
                sends.append((block.get("id"), files, params.get("caption") or ""))

    # dicts keep insertion order, so popping before re-inserting moves a
    # re-sent path to the newest position.
    found = {}
    for call_id, files, caption in sends:
        if call_id is not None and call_id in failed:
            continue
        for path in files:
            if not isinstance(path, str):
                continue
            found.pop(path, None)
            found[path] = caption
    return list(reversed(found.items()))


def main():
    cwd = sys.argv[1] if len(sys.argv) > 1 else os.getcwd()
    title = sys.argv[2] if len(sys.argv) > 2 else ""
    session_id = sys.argv[3] if len(sys.argv) > 3 else ""
    transcript = resolve_transcript(project_dir(cwd), title, session_id)
    if not transcript or not os.path.exists(transcript):
        return 1
    # The path is printed so the caller can watch the transcript's mtime
    # without repeating the newest-file search on every poll.
    sys.stdout.write("#transcript\t%s\n" % transcript)
    name = custom_title(transcript)
    if name:
        sys.stdout.write("#title\t%s\n" % name.replace("\t", " "))
    for path, caption in collect(transcript):
        sys.stdout.write("%s\t%s\n" % (path, caption.replace("\t", " ")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
