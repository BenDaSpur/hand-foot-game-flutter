#!/usr/bin/env python3
"""Set the first version: line in a pubspec.yaml file."""

from __future__ import annotations

import pathlib
import re
import sys


def set_pubspec_version(pubspec_path: str, version: str) -> None:
    path = pathlib.Path(pubspec_path)
    text = path.read_text()
    updated, count = re.subn(
        r"^version:\s*.+$",
        f"version: {version}",
        text,
        count=1,
        flags=re.M,
    )
    if count != 1:
        raise SystemExit(f"{pubspec_path} has no version: line")
    path.write_text(updated)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(f"Usage: {sys.argv[0]} <pubspec.yaml> <version>")
    set_pubspec_version(sys.argv[1], sys.argv[2])
