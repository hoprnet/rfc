#!/usr/bin/env bash

# Safety
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

# Optional debug: set DEBUG=1 env to trace
if [ "${DEBUG:-0}" = "1" ]; then
  echo "🔧 Debug tracing enabled"
  set -x
fi

for MD_FILE in "${MD_FILES[@]}"; do
  echo "============================================================"
  echo "🔄 START: $MD_FILE"

  # Run generator explicitly; capture exit code
  bash "$GENERATOR_SCRIPT" "$MD_FILE"
  rc=$?

  echo "↪ Exit code: $rc"

  if [ $rc -eq 0 ]; then
    SUCCESS_COUNT=$((SUCCESS_COUNT+1))
    echo "✅ OK: $MD_FILE"
  else
    FAIL_COUNT=$((FAIL_COUNT+1))
    FAILED_FILES+=("$MD_FILE")
    echo "❌ FAIL ($rc): $MD_FILE"
  fi
  echo "🔄 END:   $MD_FILE"
done

echo "📈 Success: $SUCCESS_COUNT  Fail: $FAIL_COUNT"

# Build include lines (newline per file)
INCLUDE_LINES=""
for MD_FILE in "${MD_FILES[@]}"; do
  base=$(basename "$MD_FILE")
  name="${base%.*}"
  gen_dir="generated/$name"
  tex_file="$gen_dir/${name}-pandoc.tex"
  if [ -f "$tex_file" ]; then
    INCLUDE_LINES+=$(printf '\\include{%s}\n' "$tex_file")
  fi
done

# Trim trailing newline
INCLUDE_LINES="${INCLUDE_LINES%$'\n'}"

if [ -z "$INCLUDE_LINES" ]; then
  echo "⚠️  No generated tex files to include. Skipping main.tex update."
  exit 1
fi

BLOCK_START="% BEGIN GENERATED RFC INCLUDES"
BLOCK_END="% END GENERATED RFC INCLUDES"

# Rebuild block text (each include already newline-terminated earlier)
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
    # Use tail -n +N (works GNU & BSD) to start from next line
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