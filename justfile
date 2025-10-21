# list all sections from the given markdown file
list-sections mdfile:
  grep -E '^#{2,4}' {{ mdfile }}

# formats all code
format:
  nix fmt

# checks all formatting, exits with non-zero if format is not correct
format-check:
  nix build .#pre-commit-check -L

# spell check all RFC markdown files
spell-check:
  cspell "rfcs/**/*.md" "*.md"

# spell check with CI mode (fails on any errors)
spell-check-ci:
  cspell --no-progress "rfcs/**/*.md" "*.md"
