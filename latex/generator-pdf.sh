#!/usr/bin/env bash

set -e
set -u
(set -o pipefail 2>/dev/null) && set -o pipefail

RFC_FOLDER="../rfcs"
GENERATOR_SCRIPT="./generator-tex.sh"
BASE_MAIN_TEX="main_base.tex"
MAIN_TEX="main.tex"

# Prepare main.tex from base
cp "$BASE_MAIN_TEX" "$MAIN_TEX"

echo "🔍 Scanning for RFC markdown files..."

[ -d "$RFC_FOLDER" ] || { echo "❌ RFC folder not found: $RFC_FOLDER"; exit 1; }
[ -f "$GENERATOR_SCRIPT" ] || { echo "❌ Generator script not found: $GENERATOR_SCRIPT"; exit 1; }
[ -f "$MAIN_TEX" ] || { echo "❌ main.tex not found in $(pwd)"; exit 1; }

MD_FILES=($(find "$RFC_FOLDER" -name "*.md" -type f | sort))
[ ${#MD_FILES[@]} -gt 0 ] || { echo "📭 No markdown files."; exit 0; }

SUCCESS_COUNT=0
FAIL_COUNT=0
FAILED_FILES=()

for MD_FILE in "${MD_FILES[@]}"; do
  echo "🔄 Processing: $MD_FILE"
  if sh "$GENERATOR_SCRIPT" "$MD_FILE"; then
    ((SUCCESS_COUNT++))
  else
    FAILED_FILES+=("$MD_FILE")
    ((FAIL_COUNT++))
  fi
done

echo "📈 Success: $SUCCESS_COUNT  Fail: $FAIL_COUNT"

# Build include lines (only for successfully generated ones)
INCLUDE_LINES=""
for MD_FILE in "${MD_FILES[@]}"; do
  base=$(basename "$MD_FILE")
  name="${base%.*}"                # e.g. 0001-rfc-process
  gen_dir="generated/$name"
  tex_file="$gen_dir/${name}-pandoc.tex"
  if [ -f "$tex_file" ]; then
    INCLUDE_LINES+="\\include{$tex_file}"
  fi
done


if [ -z "$INCLUDE_LINES" ]; then
  echo "⚠️  No generated tex files to include. Skipping main.tex update."
  exit 1
fi

# Ensure marker block exists (add if missing)
if ! grep -q "BEGIN GENERATED RFC INCLUDES" "$MAIN_TEX"; then
  awk -v inc="$INCLUDE_LINES" '
    /\\begin{document}/ && !done {
      print;
      print "% BEGIN GENERATED RFC INCLUDES";
      printf "%s", inc;
      print "% END GENERATED RFC INCLUDES";
      done=1;
      next
    }
    { print }
  ' "$MAIN_TEX" > "$MAIN_TEX.tmp" && mv "$MAIN_TEX.tmp" "$MAIN_TEX"
else
  # Replace existing block
  # macOS sed
  ESCAPED=$(printf "%s" "$INCLUDE_LINES" | sed 's/[&/\]/\\&/g')
  sed -i '' "/BEGIN GENERATED RFC INCLUDES/,/END GENERATED RFC INCLUDES/c\\
% BEGIN GENERATED RFC INCLUDES\\
$ESCAPED% END GENERATED RFC INCLUDES" "$MAIN_TEX"
fi

echo "✅ main.tex updated with includes:"
printf "%s" "$INCLUDE_LINES"

# Exit status reflects failures
[ $FAIL_COUNT -eq 0 ] || exit 1

xelatex -shell-escape main.tex


