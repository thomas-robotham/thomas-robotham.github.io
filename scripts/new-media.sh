#!/usr/bin/env bash
# Scaffold a media entry and fetch its poster frame.
#
#   ./scripts/new-media.sh <slug> <youtube-url-or-id>
#
# Creates media/<slug>.qmd and downloads the video's thumbnail to
# images/media/<slug>.jpg, so the page serves its own poster and contacts
# YouTube only when a visitor actually presses play.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ $# -ne 2 ]; then
  echo "usage: $0 <slug> <youtube-url-or-id>" >&2
  exit 1
fi

slug="$1"
raw="$2"

# Accept a full URL (youtu.be/ID, watch?v=ID) or a bare ID.
id="$raw"
case "$raw" in
  *youtu.be/*)  id="${raw##*youtu.be/}" ;;
  *watch?v=*)   id="${raw##*watch?v=}" ;;
  *embed/*)     id="${raw##*embed/}" ;;
esac
id="${id%%[&?]*}"

target="media/${slug}.qmd"
poster="images/media/${slug}.jpg"

if [ -e "$target" ]; then
  echo "error: $target already exists" >&2
  exit 1
fi

mkdir -p images/media
# maxresdefault is absent on some uploads; hqdefault always exists.
if ! curl -fsSL "https://img.youtube.com/vi/${id}/maxresdefault.jpg" -o "$poster"; then
  curl -fsSL "https://img.youtube.com/vi/${id}/hqdefault.jpg" -o "$poster"
fi
echo "created $poster ($(du -h "$poster" | cut -f1))"

sed -e "s|<slug>|${slug}|g" -e "s|<video-id>|${id}|g" media/_template.qmd.txt > "$target"
echo "created $target"
echo
echo "next: edit $target, then run 'quarto preview'"
