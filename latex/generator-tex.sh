#!/usr/bin/env bash
# Generate per‑RFC LaTeX + rendered Mermaid PNGs (bash version)

set -e
set -u
(set -o pipefail 2>/dev/null) && set -o pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 ../rfcs/RFC-0001-rfc-process/0001-rfc-process.md"
  exit 1
fi

INPUT="$1"

if [ ! -f "$INPUT" ]; then
  echo "Error: File not found: $INPUT"
  exit 1
fi

command -v mmdc    >/dev/null || { echo "mmdc missing (npm i -g @mermaid-js/mermaid-cli)"; exit 1; }
command -v pandoc  >/dev/null || { echo "pandoc missing"; exit 1; }

# realpath fallback (macOS)
if command -v realpath >/dev/null 2>&1; then
  FULLPATH="$(realpath "$INPUT")"
else
  FULLPATH="$(cd "$(dirname "$INPUT")" && pwd)/$(basename "$INPUT")"
fi

BASENAME="$(basename "$FULLPATH")"
NAME="${BASENAME%.*}"
SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
TEMPFOLDER="$SCRIPTDIR/generated/$NAME"

rm -rf "$TEMPFOLDER"
mkdir -p "$TEMPFOLDER"

echo "== Step 1: Extract & render Mermaid blocks =="

cp "$FULLPATH" "$TEMPFOLDER/$NAME.md"

MERMAID_INDEX=1
TOTAL_FOUND=0
RENDERED=0

# Read source and extract ```mermaid blocks
while IFS= read -r line; do
  if [ "$line" = '```mermaid' ]; then
    TOTAL_FOUND=$((TOTAL_FOUND+1))
    MERMAID_FILE="/tmp/mermaid_${MERMAID_INDEX}.mmd"
    PNG_FILE="$TEMPFOLDER/mermaid_${MERMAID_INDEX}.png"
    : > "$MERMAID_FILE"
    # Capture until closing ```
    while IFS= read -r inner; do
      [ "$inner" = '```' ] && break
      printf '%s\n' "$inner" >> "$MERMAID_FILE"
    done
    echo "Rendering block $MERMAID_INDEX -> $(basename "$PNG_FILE")"
    if mmdc \
      -i "$MERMAID_FILE" \
      -o "$PNG_FILE" \
      --outputFormat png \
      --width 4800 \
      --height 4800 \
      --backgroundColor white \
      --scale 4; then
      RENDERED=$((RENDERED+1))
    else
      echo "⚠️  Failed to render block $MERMAID_INDEX"
    fi
    MERMAID_INDEX=$((MERMAID_INDEX+1))
  fi
done < "$FULLPATH"

echo "Found $TOTAL_FOUND Mermaid block(s); rendered $RENDERED."

echo "== Step 2: Replace Mermaid blocks with PNG references =="

# Replace each original ```mermaid block sequentially
# Loop from 1 to (MERMAID_INDEX-1)
i=1
while [ $i -lt "$MERMAID_INDEX" ]; do
  awk -v idx="$i" '
    BEGIN { inblk=0 }
    /^```mermaid$/ {
      if(inblk==0){
        print "![Mermaid Diagram " idx "](mermaid_" idx ".png)"
        inblk=1
        next
      }
    }
    /^```$/ {
      if(inblk==1){
        inblk=0
        next
      }
    }
    inblk==0 { print }
  ' "$TEMPFOLDER/$NAME.md" > "$TEMPFOLDER/$NAME.tmp" && mv "$TEMPFOLDER/$NAME.tmp" "$TEMPFOLDER/$NAME.md"
  i=$((i+1))
done

echo "== Step 3: Convert markdown -> LaTeX with pandoc =="

pandoc \
  "$TEMPFOLDER/$NAME.md" \
  -f gfm \
  -t latex \
  -o "$TEMPFOLDER/$NAME-pandoc.tex"

echo "== Step 4: Fix image paths & enforce max width =="

# Portable sed in-place (GNU vs BSD)
if sed --version >/dev/null 2>&1; then
  SED_INPLACE=(-i)
else
  SED_INPLACE=(-i '')
fi

# Replace any bare mermaid_X.png with proper relative path
sed "${SED_INPLACE[@]}" "s|mermaid_\\([0-9][0-9]*\\)\\.png|generated/$NAME/mermaid_\\1.png|g" \
  "$TEMPFOLDER/$NAME-pandoc.tex"

# Ensure width=\maxwidth present
awk '
  /\\includegraphics/ {
    if ($0 !~ /width=\\maxwidth/) {
      sub(/\\includegraphics\[/,"\\includegraphics[width=\\maxwidth,")
    }
  }
  { print }
' "$TEMPFOLDER/$NAME-pandoc.tex" > "$TEMPFOLDER/$NAME-pandoc.tmp" && mv "$TEMPFOLDER/$NAME-pandoc.tmp" "$TEMPFOLDER/$NAME-pandoc.tex"

echo "== Step 5: Report =="

echo "Generated directory: $TEMPFOLDER"
ls -1 "$TEMPFOLDER" || true
echo "Image includes in LaTeX:"
grep -n "includegraphics" "$TEMPFOLDER/$NAME-pandoc.tex" || echo "None"
echo "PNG files:"
for p in "$TEMPFOLDER"/mermaid_*.png; do
  [ -f "$p" ] && echo " - $(basename "$p") ($(wc -c < "$p") bytes)"
done

echo "Done: $TEMPFOLDER/$NAME-pandoc.tex"