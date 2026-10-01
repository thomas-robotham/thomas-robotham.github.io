#!/usr/bin/env bash
# Scaffold a new research highlight.
#
#   ./scripts/new-highlight.sh <slug> [source-image]
#
# Creates highlights/<slug>.qmd from the template and, if a source image is
# given, generates the 16:9 card thumbnail at images/cards/<slug>.jpg.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ $# -lt 1 ]; then
  echo "usage: $0 <slug> [source-image]" >&2
  exit 1
fi

slug="$1"
target="highlights/${slug}.qmd"

if [ -e "$target" ]; then
  echo "error: $target already exists" >&2
  exit 1
fi

sed "s|<slug>|${slug}|g" highlights/_template.qmd.txt > "$target"
echo "created $target"

if [ $# -ge 2 ]; then
  ./scripts/make-card-image.sh "$2" "$slug"
fi

echo
echo "next: edit $target, then run 'quarto preview'"
