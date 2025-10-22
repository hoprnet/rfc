#!/usr/bin/env bash

# Safety
set -e
set -u
(set -o pipefail 2>/dev/null) && set -o pipefail

RFC_FOLDER="../rfcs"
GENERATOR_SCRIPT="./generator-tex.sh"
BASE_MAIN_TEX="main_base.tex"
MAIN_TEX="main.tex"

echo "🔍 Scanning for RFC markdown files..."

[ -d "$RFC_FOLDER" ] || { echo "❌ RFC folder not found: $RFC_FOLDER"; exit 1; }
[ -f "$GENERATOR_SCRIPT" ] || { echo "❌ Generator script not found: $GENERATOR_SCRIPT"; exit 1; }
[ -f "$BASE_MAIN_TEX" ] || { echo "❌ $BASE_MAIN_TEX not found in $(pwd)"; exit 1; }

# Collect markdown files
MD_FILES=()
while IFS= read -r f; do
  MD_FILES+=("$f")
done < <(find "$RFC_FOLDER" -type f -name "*.md" | sort)

echo "📄 Files detected: ${#MD_FILES[@]}"
printf ' - %s\n' "${MD_FILES[@]}"

[ ${#MD_FILES[@]} -gt 0 ] || { echo "📭 No markdown files."; exit 1; }

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

  # Run generator; under set -e we must guard with 'if'
  if bash "$GENERATOR_SCRIPT" "$MD_FILE"; then
    SUCCESS_COUNT=$((SUCCESS_COUNT+1))
    echo "✅ OK: $MD_FILE"
  else
    rc=$?
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


INSERT_BLOCK="% (auto-filled by generator-pdf.sh)"

# Insert generated RFCs into main.tex
lineNo="$(grep -nF "$INSERT_BLOCK" "$BASE_MAIN_TEX" | head -1 | cut -d: -f1)"
[ -n "${lineNo}" ] || { echo "❌ Insert block marker not found in $BASE_MAIN_TEX: $INSERT_BLOCK"; exit 1; }
{
  # Up to and including \begin{document}
  head -n "$lineNo" "$BASE_MAIN_TEX"
  # Our generated block
  printf '%s\n' "$INCLUDE_LINES"
  # Remainder of file (start AFTER that line)
  # Use tail -n +N (works GNU & BSD) to start from next line
  tail -n +"$((lineNo+1))" "$BASE_MAIN_TEX"
} > "$MAIN_TEX"

echo "✅ main.tex updated with includes (no duplication)"
printf '%s\n' "$INCLUDE_LINES"

[ $FAIL_COUNT -eq 0 ] || exit 1

echo "🖨  Building PDF..."
xelatex -synctex=1 -interaction=nonstopmode -halt-on-error -shell-escape main.tex
echo "✅ Done: main.pdf"