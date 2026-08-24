#!/usr/bin/env bash
# Prints UTC YYYY-MM-DD dates for unprocessed first-parent commits after the
# last "chore: bump build version to" commit, oldest first.
# If no bump commit exists, prints HEAD's date once so history is not replayed.
set -euo pipefail

subject_of() {
  git log -1 --format='%s' "$1"
}

date_of() {
  local ts
  ts=$(git show -s --format='%cI' "$1")
  date -u -d "$ts" +%Y-%m-%d
}

is_bump_commit() {
  local subject
  subject=$(subject_of "$1")
  [[ "$subject" == 'chore: bump build version to '* ]]
}

LAST_BUMP=$(git log --first-parent --grep='^chore: bump build version to ' -1 --format='%H')

if [ -z "${LAST_BUMP}" ]; then
  if is_bump_commit HEAD; then
    exit 0
  fi
  date_of HEAD
  exit 0
fi

while IFS= read -r commit; do
  if [ -z "$commit" ]; then
    continue
  fi
  if is_bump_commit "$commit"; then
    continue
  fi
  date_of "$commit"
done < <(git log --first-parent --reverse --format='%H' "${LAST_BUMP}..HEAD")
