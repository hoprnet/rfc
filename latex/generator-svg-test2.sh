#!/usr/bin/env bash
# filepath: /Users/michal/dev/hoprnet/rfc/latex/generator-svg-test.sh
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

echo "== Step 2: Convert markdown to LaTeX (without mermaid-filter) =="
cp "$FULLPATH" "$TEMPFOLDER/$NAME.md"
pandoc \
  "$TEMPFOLDER/$NAME.md" \
  -f gfm \
  -t latex \
  -o "$TEMPFOLDER/$NAME-base.tex"

echo "== Step 3: Replace mermaid blocks with includegraphics =="
# Create the final LaTeX file by replacing mermaid blocks
COUNTER=1
sed '/^```mermaid$/,/^```$/c\
\\begin{figure}[h]\
\\centering\
\\includesvg[width=0.8\\textwidth]{MERMAID_PLACEHOLDER}\
\\end{figure}' "$TEMPFOLDER/$NAME-base.tex" > "$TEMPFOLDER/$NAME-temp.tex"

# Replace placeholders with actual SVG file paths
COUNTER=1
cp "$TEMPFOLDER/$NAME-temp.tex" "$TEMPFOLDER/$NAME-pandoc.tex"
while [ $COUNTER -lt $MERMAID_COUNTER ]; do
  sed -i '' "s|MERMAID_PLACEHOLDER|generated/$NAME/mermaid_$COUNTER|" "$TEMPFOLDER/$NAME-pandoc.tex"
  ((COUNTER++))
  break  # Only replace first occurrence, then loop for next
done

# Fix multiple replacements properly
COUNTER=1
while [ $COUNTER -lt $MERMAID_COUNTER ]; do
  if [ $COUNTER -eq 1 ]; then
    sed -i '' "s|generated/$NAME/mermaid_$COUNTER|generated/$NAME/mermaid_$COUNTER|" "$TEMPFOLDER/$NAME-pandoc.tex"
  else
    sed -i '' "0,/MERMAID_PLACEHOLDER/s//generated\/$NAME\/mermaid_$COUNTER/" "$TEMPFOLDER/$NAME-pandoc.tex"
  fi
  ((COUNTER++))
done

echo "== Step 4: Clean up LaTeX file =="
# Remove any remaining mermaid code blocks that weren't processed
sed -i '' '/\\begin{verbatim}/,/\\end{verbatim}/d' "$TEMPFOLDER/$NAME-pandoc.tex"

echo "== Outputs =="
ls -1 "$TEMPFOLDER" || true
echo "Generated SVG files:"
ls -1 "$TEMPFOLDER"/*.svg 2>/dev/null || echo "No SVG files found"
echo "LaTeX file: $TEMPFOLDER/$NAME-pandoc.tex"

echo "== LaTeX includes =="
grep -n "includesvg" "$TEMPFOLDER/$NAME-pandoc.tex" || echo "No includesvg found"