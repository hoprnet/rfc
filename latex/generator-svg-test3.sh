#!/usr/bin/env bash
# filepath: /Users/michal/dev/hoprnet/rfc/latex/generator-svg-test3.sh
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

echo "== Step 1: Extract and render mermaid blocks to SVG =="
cp "$FULLPATH" "$TEMPFOLDER/$NAME.md"
MERMAID_COUNTER=1

while IFS= read -r line; do
  if [[ "$line" == '```mermaid' ]]; then
    echo "Found mermaid block $MERMAID_COUNTER"
    # Extract mermaid content until closing ```
    MERMAID_FILE="/tmp/mermaid_$MERMAID_COUNTER.mmd"
    SVG_FILE="$TEMPFOLDER/mermaid_$MERMAID_COUNTER.svg"
    
    # Read mermaid content
    > "$MERMAID_FILE"  # Clear file
    while IFS= read -r mermaid_line; do
      if [[ "$mermaid_line" == '```' ]]; then
        break
      fi
      echo "$mermaid_line" >> "$MERMAID_FILE"
    done
    
    # Render to SVG
    echo "Rendering mermaid block $MERMAID_COUNTER to SVG..."
    mmdc -i "$MERMAID_FILE" -o "$SVG_FILE" --outputFormat svg || echo "Failed to render mermaid block $MERMAID_COUNTER"
    
    ((MERMAID_COUNTER++))
  fi
done < "$FULLPATH"

echo "== Step 2: Replace mermaid blocks with SVG references in markdown =="
COUNTER=1
while [ $COUNTER -lt $MERMAID_COUNTER ]; do
  # Replace each mermaid block with an SVG image reference
  awk -v counter="$COUNTER" '
    BEGIN { in_mermaid = 0; skip = 0 }
    /^```mermaid$/ { 
      if (!skip) {
        print "![Mermaid Diagram " counter "](mermaid_" counter ".svg)"
        in_mermaid = 1
        skip = 1
        next
      }
    }
    /^```$/ && in_mermaid { 
      in_mermaid = 0
      next
    }
    !in_mermaid { print }
  ' "$TEMPFOLDER/$NAME.md" > "$TEMPFOLDER/$NAME-temp.md"
  
  mv "$TEMPFOLDER/$NAME-temp.md" "$TEMPFOLDER/$NAME.md"
  ((COUNTER++))
done

echo "== Step 3: Convert modified markdown to LaTeX =="
pandoc \
  "$TEMPFOLDER/$NAME.md" \
  -f gfm \
  -t latex \
  -o "$TEMPFOLDER/$NAME-pandoc.tex"

echo "== Step 4: Fix SVG paths in LaTeX for includesvg =="
# Replace \includegraphics with \includesvg and fix paths
sed -i '' 's/\\includegraphics{mermaid_\([0-9]*\)\.svg}/\\includesvg[width=0.8\\textwidth]{mermaid_\1}/' "$TEMPFOLDER/$NAME-pandoc.tex"

echo "== Outputs =="
ls -1 "$TEMPFOLDER" || true
echo "Generated SVG files:"
ls -1 "$TEMPFOLDER"/*.svg 2>/dev/null || echo "No SVG files found"
echo "Modified markdown file: $TEMPFOLDER/$NAME.md"
echo "LaTeX file: $TEMPFOLDER/$NAME-pandoc.tex"

echo "== LaTeX includes =="
grep -n "includesvg\|includegraphics" "$TEMPFOLDER/$NAME-pandoc.tex" || echo "No include commands found"

echo "== Modified markdown preview =="
echo "First 10 lines around SVG references:"
grep -n -A2 -B2 "Mermaid Diagram" "$TEMPFOLDER/$NAME.md" || echo "No SVG references found"