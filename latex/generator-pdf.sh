set -euo pipefail

echo "== Toolchain =="
which pandoc || { echo "pandoc missing"; exit 1; }
which mermaid-filter || { echo "mermaid-filter missing (npm i -g mermaid-filter)"; exit 1; }
which mmdc || { echo "mmdc missing (npm i -g @mermaid-js/mermaid-cli)"; exit 1; }

INPUT=../rfcs/RFC-0001-rfc-process/0001-rfc-process.md
OUTDIR=./generated
mkdir -p "$OUTDIR"

echo "== Checking code block attributes =="
pandoc "$INPUT" -f gfm -t json | grep -A3 '"mermaid"' || echo "No mermaid blocks found in JSON."

echo "== Converting =="
pandoc "$INPUT" \
  -f gfm -t latex \
  -F mermaid-filter \
  --metadata mermaid_format=pdf \
  --verbose \
  -o "$OUTDIR/0001-rfc-process.tex"

echo "== Result =="
grep -n 'includegraphics' "$OUTDIR/0001-rfc-process.tex" || echo "No includegraphics produced."

ls -1 "$OUTDIR" | grep -E 'mermaid|png|pdf' || echo "No diagram file emitted."