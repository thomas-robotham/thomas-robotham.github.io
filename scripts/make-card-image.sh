#!/usr/bin/env bash
# Generate a web-sized card thumbnail.
#
#   ./scripts/make-card-image.sh <source-image> <slug> [output-dir]
#
# Writes <output-dir>/<slug>.jpg, capped at 900px on the long edge.
# output-dir defaults to images/cards; positions use images/positions.
# Cards crop with object-fit: cover, so keep the subject central.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ $# -lt 2 ] || [ $# -gt 3 ]; then
  echo "usage: $0 <source-image> <slug> [output-dir]" >&2
  exit 1
fi

src="$1"
slug="$2"
dir="${3:-images/cards}"
out="${dir}/${slug}.jpg"

mkdir -p "$dir"
sips -s format jpeg -s formatOptions 82 -Z 900 "$src" --out "$out" >/dev/null
echo "created $out ($(du -h "$out" | cut -f1))"
