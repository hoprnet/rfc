#!/usr/bin/env bash
# Generate per-RFC LaTeX + Mermaid PNGs (single-pass, no awk mermaid replacement)

set -e
set -u
(set -o pipefail 2>/dev/null) && set -o pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 ../rfcs/RFC-0001-rfc-process/0001-rfc-process.md"
  exit 1
fi

INPUT="$1"
[ -f "$INPUT" ] || { echo "Error: File not found: $INPUT"; exit 1; }

command -v mmdc >/dev/null || { echo "mmdc missing (npm i -g @mermaid-js/mermaid-cli)"; exit 1; }
command -v pandoc >/dev/null || { echo "pandoc missing"; exit 1; }

if command -v realpath >/dev/null 2>&1; then
  FULLPATH="$(realpath "$INPUT")"
else
  FULLPATH="$(cd "$(dirname "$INPUT")" && pwd)/$(basename "$INPUT")"
fi

BASENAME="$(basename "$FULLPATH")"
NAME="${BASENAME%.*}"
SCRIPTDIR="$(cd "$(dirname "$0")" && pwd)"
OUTDIR="$SCRIPTDIR/generated/$NAME"

rm -rf "$OUTDIR"
mkdir -p "$OUTDIR"

MERMAID_IDX=1
RENDERED=0

SRC="$FULLPATH"
DST_MD="$OUTDIR/$NAME.md"

echo "== Extract + render (single pass) =="

: > "$DST_MD"


cat > puppeteer-config.json <<'JSON'
{
  "args": ["--no-sandbox", "--disable-setuid-sandbox"]
}
JSON

# Single pass: write normal lines, replace mermaid block immediately
while IFS= read -r line; do
  if [ "$line" = '```mermaid' ]; then
    MERM_FILE="/tmp/mermaid_${MERMAID_IDX}.mmd"
    : > "$MERM_FILE"
    # collect block
    while IFS= read -r inner; do
      [ "$inner" = '```' ] && break
      printf '%s\n' "$inner" >> "$MERM_FILE"
    done
    PNG_FILE="$OUTDIR/mermaid_${MERMAID_IDX}.png"
    echo "Rendering mermaid block $MERMAID_IDX -> $(basename "$PNG_FILE")"
    if mmdc -i "$MERM_FILE" -o "$PNG_FILE" --outputFormat png --width 4800 --height 4800 --backgroundColor white --scale 4  --puppeteerConfigFile puppeteer-config.json; then
      RENDERED=$((RENDERED+1))
    else
      echo "⚠️  Render failed for block $MERMAID_IDX"
    fi
    # insert image reference
    printf '![Mermaid Diagram %d](mermaid_%d.png)\n' "$MERMAID_IDX" "$MERMAID_IDX" >> "$DST_MD"
    MERMAID_IDX=$((MERMAID_IDX+1))
  else
    printf '%s\n' "$line" >> "$DST_MD"
  fi
done < "$SRC"

echo "Rendered $RENDERED Mermaid diagram(s)."

echo "== Pandoc convert =="
pandoc "$DST_MD" -f gfm -t latex -o "$OUTDIR/$NAME-pandoc.tex"

echo "== Fix image paths + width =="

# Portable sed in-place
if sed --version >/dev/null 2>&1; then
  SED_I=(-i)
else
  SED_I=(-i '')
fi

sed "${SED_I[@]}" "s|mermaid_\\([0-9][0-9]*\\)\\.png|generated/$NAME/mermaid_\\1.png|g" "$OUTDIR/$NAME-pandoc.tex"

# Ensure width=\maxwidth (only if includegraphics present)
tmp="$OUTDIR/$NAME-pandoc.tmp"
awk '
/\\includegraphics/ {
  if ($0 !~ /width=\\maxwidth/) {
    sub(/\\includegraphics\[/,"\\includegraphics[width=\\maxwidth,")
  }
}
{ print }
' "$OUTDIR/$NAME-pandoc.tex" > "$tmp" && mv "$tmp" "$OUTDIR/$NAME-pandoc.tex"

echo "== Summary =="
echo "Markdown: $DST_MD"
echo "LaTeX:    $OUTDIR/$NAME-pandoc.tex"
echo "Images:"
ls -1 "$OUTDIR"/mermaid_*.png 2>/dev/null || echo "None"
echo "Done: $OUTDIR/$NAME-pandoc.tex"