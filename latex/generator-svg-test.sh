#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 ../rfcs/RFC-0001-rfc-process/0001-rfc-process.md"
  exit 1
fi

INPUT="$1"

if [ ! -f "$INPUT" ]; then
  echo "Error: File not found: $INPUT"
  exit 1
fi

command -v mmdc >/dev/null || { echo "mmdc missing (npm i -g @mermaid-js/mermaid-cli)"; exit 1; }
command -v pandoc >/dev/null || { echo "pandoc missing"; exit 1; }

FULLPATH="$(realpath "$INPUT")"
FILEDIR="$(dirname "$FULLPATH")"
BASENAME="$(basename "$FULLPATH")"
NAME="${BASENAME%.*}"
SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"

TEMPFOLDER="$SCRIPTDIR/generated/$NAME"
rm -rf "$TEMPFOLDER"
mkdir -p "$TEMPFOLDER"

echo "== Mermaid note =="
echo "mmdc renders .mmd (Mermaid) files, not generic markdown with embedded diagrams."
echo "This script assumes INPUT is a pure .mmd file. If it's markdown with mermaid code blocks, use pandoc + mermaid-filter instead."

#echo "== Rendering Mermaid to PDF =="
#mmdc -i "$FULLPATH" --outputFormat png --pdfFit -o "$TEMPFOLDER/$NAME.pdf"

echo "== Rendering Mermaid to SVG =="
mmdc -i "$FULLPATH" -o "$TEMPFOLDER/$NAME.svg" --outputFormat svg

echo "== Converting (raw markdown -> TEX via pandoc) =="
cp "$FULLPATH" "$TEMPFOLDER/$NAME.md"
pandoc \
  "$TEMPFOLDER/$NAME.md" \
  -f gfm \
  -t latex \
  -F mermaid-filter  \
  --metadata mermaid_format=svg \
  -o "$TEMPFOLDER/$NAME-pandoc.tex"

echo "== Outputs =="
ls -1 "$TEMPFOLDER" || true
[ -f "$TEMPFOLDER/$NAME.pdf" ] && echo "Mermaid PDF: $TEMPFOLDER/$NAME.pdf"
[ -f "$FILEDIR/$NAME-pandoc.pdf" ] && echo "Pandoc PDF: $FILEDIR/$NAME-pandoc.pdf"

echo