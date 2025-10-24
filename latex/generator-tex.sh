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
# Optional: grayscale conversion (ImageMagick)
if command -v convert >/dev/null; then
  GRAYSCALE_OK=1
else
  GRAYSCALE_OK=0
  echo "ImageMagick convert not found: mermaid PNGs will stay colored"
fi

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
      # Grayscale conversion
      if [ "$GRAYSCALE_OK" -eq 1 ]; then
        convert "$PNG_FILE" -colorspace Gray "$PNG_FILE"
      fi
    else
      echo "⚠️  Render failed for block $MERMAID_IDX"
      exit 1
    fi
    # insert image reference
    printf '![Mermaid Diagram %d](mermaid_%d.png)\n' "$MERMAID_IDX" "$MERMAID_IDX" >> "$DST_MD"
    MERMAID_IDX=$((MERMAID_IDX+1))
  else
    printf '%s\n' "$line" >> "$DST_MD"
  fi
done < "$SRC"

echo "Rendered $RENDERED Mermaid diagram(s)."

# Prepare tables for Pandoc
table_sep_matches="$(grep -nE '^\|\s*:?-{3,}:?\s*(\|\s*:?-{3,}:?\s*)*\|\s*$' "$DST_MD" | cut -d: -f1 || true)"
# Fix the table_sep_matches if there are no matches
if [ -n "$table_sep_matches" ]; then
  table_sep_json="$(printf '%s\n' "$table_sep_matches" | jq -s .)"
else
  table_sep_json="[]"
fi
table_count="$(printf '%s\n' "$table_sep_json" | jq 'length')"
echo "Tables found: $table_count"
echo "Table separator lines JSON: $table_sep_json"

echo "== Table separator line audit =="
echo "$table_sep_json" | jq -r '.[]' | while read -r lineno; do
  line_content="$(sed -n "${lineno}p" "$DST_MD")"
  line_len=${#line_content}
  col_count="$(printf '%s\n' "$line_content" | awk -F'|' '{print NF-2}')"
  echo "Line ${lineno}: columns=${col_count} length=${line_len}"
  if [ "$line_len" -lt 80 ]; then

    # Count dashes per column (ignore spaces and colons)
    dash_json="$(
      trimmed="${line_content#|}"; trimmed="${trimmed%|}"
      IFS='|' read -r -a cols <<< "$trimmed"
      first=1
      printf '['
      for col in "${cols[@]}"; do
        cell="$(echo "$col" | tr -d ' \t:')"
        dashes="$(echo -n "$cell" | tr -cd '-' | wc -c | tr -d ' ')"
        if [ $first -eq 0 ]; then printf ','; fi
        printf '%s' "$dashes"
        first=0
      done
      printf ']'
    )"

    # Force array length == col_count (trim or pad)
    dash_len="$(echo "$dash_json" | jq 'length')"
    if [ "$dash_len" -gt "$col_count" ]; then
      dash_json="$(echo "$dash_json" | jq ".[0:$col_count]")"
    elif [ "$dash_len" -lt "$col_count" ]; then
      # Pad missing columns with 0 (will be raised to min 3 below)
      missing=$((col_count - dash_len))
      pad="$(jq -n --argjson m "$missing" '[range($m)|0]')"
      dash_json="$(jq -n --argjson a "$dash_json" --argjson p "$pad" '$a + $p')"
    fi

    # Add all dashes in the columns
    dash_sum="$(echo "$dash_json" | jq 'add')"

    # Calculate percentages of columns widths (by the dash counts)
    dash_pct_json="$(echo "$dash_json" | jq --argjson s "$dash_sum" 'map(if $s>0 then ((. / $s)) else 0 end)')"

    # Count dashes to have according to percentages
    dashesToHavePerColumn="$(echo "$dash_pct_json" | jq 'map((. * 100)|ceil)')"

    echo "  Dashes per column: $dash_json (sum=$dash_sum) Percentages: $dash_pct_json, need more dashes to reach at 80 chars, distributing as: $dashesToHavePerColumn"

    # Build new table separator line from dashesToHavePerColumn
    new_sep_line="|"
    while read -r count; do
      # enforce minimum 3 dashes per Markdown spec
      [ "$count" -lt 3 ] && count=3
      new_sep_line="${new_sep_line} $(printf '%*s' "$count" | tr ' ' -) |"
    done < <(echo "$dashesToHavePerColumn" | jq -r '.[]')

    # new_sep_line now like: | ----- | -------- | --- |
    # TODO: replace original separator line if desired:
    # sed -i '' "${lineno}s|.*|${new_sep_line}|" "$DST_MD"

    echo "  Generated separator: $new_sep_line"

    # Replace original separator line at $lineno with $new_sep_line (portable sed)
    escaped_new_sep_line="$(printf '%s' "$new_sep_line" | sed 's/[&/]/\\&/g')"
    if sed --version >/dev/null 2>&1; then
      # GNU sed
      sed -i "${lineno}s/.*/$escaped_new_sep_line/" "$DST_MD"
    else
      # BSD sed (macOS) requires empty suffix
      sed -i '' "${lineno}s/.*/$escaped_new_sep_line/" "$DST_MD"
    fi

  fi
done

echo "== Pandoc convert =="
pandoc "$DST_MD" \
  --lua-filter=./assets/filters/bubble.lua \
  -f markdown \
  -t latex \
  -o "$OUTDIR/$NAME-pandoc.tex"

echo "== Fix image paths + width =="

# Portable sed in-place
if sed --version >/dev/null 2>&1; then
  SED_I=(-i)
else
  SED_I=(-i '')
fi

sed "${SED_I[@]}" "s|mermaid_\\([0-9][0-9]*\\)\\.png|$NAME/mermaid_\\1.png|g" "$OUTDIR/$NAME-pandoc.tex"


echo "== Extract metadata =="
echo "Extracting metadata from $FULLPATH"
# Extract metadata from Markdown
rfc_title=$(grep -m1 '^- \*\*Title:\*\*' "$FULLPATH" | sed 's/^- \*\*Title:\*\* *//' || echo "UNDEFINED")
rfc_author=$(grep -m1 '^- \*\*Author(s):\*\*' "$FULLPATH" | sed 's/^- \*\*Author(s):\*\* *//' || echo "UNDEFINED")
rfc_number=$(grep -m1 '^- \*\*RFC Number:\*\*' "$FULLPATH" | sed 's/^- \*\*RFC Number:\*\* *//' || echo "UNDEFINED")
rfc_date=$(grep -m1 '^- \*\*Updated:\*\*' "$FULLPATH" | sed 's/^- \*\*Updated:\*\* *//' || echo "UNDEFINED")

echo "Title:  $rfc_title"
echo "Author: $rfc_author"
echo "Number: $rfc_number"
echo "Date:   $rfc_date"

# Prepend metadata macro to .tex file (macOS/BSD sed syntax)
sed "${SED_I[@]}" "1i\\
\\\rfcnumber{${rfc_number}}\\
\\\rfctitle{${rfc_title}}\\
\\\rfcdate{${rfc_date}}\\
\\\rfcauthor{${rfc_author}}\\
" "$OUTDIR/$NAME-pandoc.tex"

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
rm puppeteer-config.json
echo "Done: $OUTDIR/$NAME-pandoc.tex"