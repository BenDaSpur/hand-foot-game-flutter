#!/usr/bin/env python3
"""Print the first git ref whose pubspec.yaml already has the given version."""

from __future__ import annotations

import re
import subprocess
import sys


def pubspec_version_at(ref: str) -> str | None:
    result = subprocess.run(
        ["git", "show", f"{ref}:pubspec.yaml"],
        capture_output=True,
        text=True,
        check=False,
    )
    if result.returncode != 0:
        return None
    match = re.search(r"^version:\s*(.+)$", result.stdout, flags=re.M)
    if match is None:
        return None
    return match.group(1).strip()


def find_reserved_ref(
    version: str,
    current_ref: str,
    other_refs: list[str],
) -> str | None:
    for ref in other_refs:
        if ref == current_ref:
            continue
        if pubspec_version_at(ref) == version:
            return ref
    return None


if __name__ == "__main__":
    if len(sys.argv) < 3:
        raise SystemExit(
            f"Usage: {sys.argv[0]} <version> <current_ref> [other_ref...]",
        )
    reserved = find_reserved_ref(sys.argv[1], sys.argv[2], sys.argv[3:])
    if reserved is None:
        raise SystemExit(1)
    print(reserved)
