#!/usr/bin/env python3
"""Migrate zsh history to fish history format, skipping duplicates."""

import os
import re
import time

ZSH_HISTORY = os.path.expanduser("~/.zsh_history")
FISH_HISTORY = os.path.expanduser("~/.local/share/fish/fish_history")


def parse_zsh_history(path: str) -> list[tuple[int, str]]:
    with open(path, "rb") as f:
        content = f.read().decode("utf-8", errors="replace")

    entries = []
    lines = content.splitlines()
    i = 0
    while i < len(lines):
        line = lines[i]
        # Extended history format: ": timestamp:elapsed;command"
        m = re.match(r"^: (\d+):\d+;(.*)", line)
        if m:
            timestamp = int(m.group(1))
            cmd = m.group(2)
        elif line.strip() and not line.startswith(":"):
            timestamp = 0
            cmd = line
        else:
            i += 1
            continue

        # Handle multi-line commands (backslash continuation)
        while cmd.endswith("\\") and i + 1 < len(lines):
            i += 1
            cmd = cmd[:-1] + "\n" + lines[i]

        entries.append((timestamp, cmd.strip()))
        i += 1

    return entries


def parse_fish_history(path: str) -> set[str]:
    if not os.path.exists(path):
        return set()

    existing = set()
    with open(path) as f:
        for line in f:
            m = re.match(r"^- cmd: (.*)", line)
            if m:
                existing.add(m.group(1))
    return existing


def main() -> None:
    zsh_entries = parse_zsh_history(ZSH_HISTORY)
    existing_cmds = parse_fish_history(FISH_HISTORY)

    now = int(time.time())
    added = 0

    with open(FISH_HISTORY, "a") as f:
        for timestamp, cmd in zsh_entries:
            if not cmd or cmd in existing_cmds:
                continue
            # Fish history stores cmd as single line; skip genuine multi-line for safety
            display_cmd = cmd.replace("\n", "; ")
            f.write(f"- cmd: {display_cmd}\n")
            f.write(f"  when: {timestamp if timestamp else now}\n")
            existing_cmds.add(cmd)
            added += 1

    print(f"Done: {added} entries added ({len(zsh_entries)} total in zsh history).")


if __name__ == "__main__":
    main()
