#!/usr/bin/env bash
# Scaffold an open student position.
#
#   ./scripts/new-position.sh <slug>
#
# Creates positions/<slug>.qmd from the template. Delete the file when the
# position is filled -- when the folder holds none, the landing page section
# removes itself and the standing invitation is shown instead.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ $# -ne 1 ]; then
  echo "usage: $0 <slug>" >&2
  exit 1
fi

slug="$1"
target="positions/${slug}.qmd"

if [ -e "$target" ]; then
  echo "error: $target already exists" >&2
  exit 1
fi

cp positions/_template.qmd.txt "$target"
echo "created $target"
echo
echo "next: edit $target, then run 'quarto preview'"
