#!/usr/bin/env bash
# Scaffold an interactive 3D model entry.
#
#   ./scripts/new-model.sh <slug> <path-to.obj> [path-to.mtl]
#
# Copies the model into assets/models/ and creates models/<slug>.qmd.
# You still need a poster image at images/models/<slug>.jpg -- generate one with
#   ./scripts/make-card-image.sh <screenshot> <slug> images/models
set -euo pipefail

cd "$(dirname "$0")/.."

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
  echo "usage: $0 <slug> <path-to.obj> [path-to.mtl]" >&2
  exit 1
fi

slug="$1"; obj="$2"; mtl="${3:-}"
target="models/${slug}.qmd"

[ -e "$target" ] && { echo "error: $target already exists" >&2; exit 1; }
[ -f "$obj" ]    || { echo "error: $obj not found" >&2; exit 1; }

mkdir -p assets/models images/models
cp "$obj" "assets/models/${slug}.obj"
echo "copied $(du -h "assets/models/${slug}.obj" | cut -f1) -> assets/models/${slug}.obj"

sed -e "s|<slug>|${slug}|g" models/_template.qmd.txt > "$target"

if [ -n "$mtl" ] && [ -f "$mtl" ]; then
  cp "$mtl" "assets/models/${slug}.mtl"
  echo "copied materials -> assets/models/${slug}.mtl"
else
  # No materials: drop the mtl line so the viewer does not request a missing file.
  sed -i '' "/^mtl:/d" "$target"
fi

echo "created $target"
echo
echo "next: add a poster at images/models/${slug}.jpg, then run 'quarto preview'"
