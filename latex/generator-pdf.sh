#!/usr/bin/env bash

set -e
set -u
(set -o pipefail 2>/dev/null) && set -o pipefail

RFC_FOLDER="../rfcs"
GENERATOR_SCRIPT="./generator-tex.sh"
BASE_MAIN_TEX="main_base.tex"
MAIN_TEX="main.tex"

# Rebuild main.tex from base each run
cp "$BASE_MAIN_TEX" "$MAIN_TEX"

echo "🔍 Scanning for RFC markdown files..."

[ -d "$RFC_FOLDER" ] || { echo "❌ RFC folder not found: $RFC_FOLDER"; exit 1; }
[ -f "$GENERATOR_SCRIPT" ] || { echo "❌ Generator script not found: $GENERATOR_SCRIPT"; exit 1; }
[ -f "$MAIN_TEX" ] || { echo "❌ main.tex not found in $(pwd)"; exit 1; }

# Collect markdown files
MD_FILES=()
while IFS= read -r f; do
  MD_FILES+=("$f")
done < <(find "$RFC_FOLDER" -type f -name "*.md" | sort)

echo "📄 Files detected: ${#MD_FILES[@]}"
printf ' - %s\n' "${MD_FILES[@]}"

[ ${#MD_FILES[@]} -gt 0 ] || { echo "📭 No markdown files."; exit 0; }

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_FILES=()
INCLUDE_LINES=""

for MD_FILE in "${MD_FILES[@]}"; do
  echo "============================================================"
  echo "🔄 START: $MD_FILE"

  base=$(basename "$MD_FILE")
  name="${base%.*}"
  gen_dir="generated/$name"
  tex_file="$gen_dir/${name}-pandoc.tex"
  mkdir -p "$gen_dir"

  # Generate .tex file
  pandoc "$MD_FILE" --lua-filter=../latex/bubble.lua -f markdown -t latex -o "$tex_file"

  # Extract metadata from Markdown
  rfc_title=$(grep -m1 '^# ' "$MD_FILE" | sed 's/^# *//;s/:.*//')
  rfc_author=$(grep -m1 '^-\*\*Author(s):\*\*' "$MD_FILE" | sed 's/.*: *//')
  rfc_number=$(grep -m1 '^-\*\*RFC Number:\*\*' "$MD_FILE" | sed 's/.*: *//')
  rfc_number="RFC-$rfc_number"

  # Prepend metadata macro to .tex file (macOS/BSD sed syntax)
  sed -i '' "1i\\
\\setrfcmeta{$rfc_title}{$rfc_author}{$rfc_number}
" "$tex_file"

  # Build include line
  if [ -f "$tex_file" ]; then
    INCLUDE_LINES+=$(printf '\\include{%s}\n' "$tex_file")
    SUCCESS_COUNT=$((SUCCESS_COUNT+1))
  else
    FAILED_FILES+=("$MD_FILE")
    FAIL_COUNT=$((FAIL_COUNT+1))
  fi

  echo "🔄 END:   $MD_FILE"
done

# Trim trailing newline
INCLUDE_LINES="${INCLUDE_LINES%$'\n'}"

if [ -z "$INCLUDE_LINES" ]; then
  echo "⚠️  No generated tex files to include. Skipping main.tex update."
  exit 1
fi

BLOCK_START="% BEGIN GENERATED RFC INCLUDES"
BLOCK_END="% END GENERATED RFC INCLUDES"
BLOCK_CONTENT="$BLOCK_START"$'\n'"$INCLUDE_LINES"$'\n'"$BLOCK_END"

tmp_clean="$MAIN_TEX.tmp.clean"
tmp_new="$MAIN_TEX.tmp.new"

# 1. Strip any previously generated block
if grep -q "BEGIN GENERATED RFC INCLUDES" "$MAIN_TEX"; then
  # Remove from start marker through end marker (inclusive)
  sed "/$BLOCK_START/,/$BLOCK_END/d" "$MAIN_TEX" > "$tmp_clean"
else
  cp "$MAIN_TEX" "$tmp_clean"
fi

# 2. Insert the new block immediately after the first \begin{document}
if grep -q '\\begin{document}' "$tmp_clean"; then
  lineNo="$(grep -n '\\begin{document}' "$tmp_clean" | head -1 | cut -d: -f1)"
  {
    # Up to and including \begin{document}
    head -n "$lineNo" "$tmp_clean"
    # Our generated block
    printf '%s\n' "$BLOCK_CONTENT"
    # Remainder of file (start AFTER that line)
    tail -n +"$((lineNo+1))" "$tmp_clean"
  } > "$tmp_new"
else
  # Fallback: append block at end
  cp "$tmp_clean" "$tmp_new"
  printf '\n%s\n' "$BLOCK_CONTENT" >> "$tmp_new"
fi

mv "$tmp_new" "$MAIN_TEX"
rm -f "$tmp_clean"

echo "✅ main.tex updated with includes (no duplication)"
printf '%s\n' "$INCLUDE_LINES"

[ $FAIL_COUNT -eq 0 ] || exit 1

echo "🖨  Building PDF..."
xelatex -interaction=nonstopmode -halt-on-error -shell-escape main.tex >/dev/null
echo "✅ Done: main.pdf"