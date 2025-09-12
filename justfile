# list all sections from the given markdown file
list-sections mdfile:
  grep -E '^#{2,4}' {{ mdfile }}

# formats all code
format:
  nix fmt

# checks all formatting, exits with non-zero if format is not correct
format-check: 
  nix build .#pre-commit-check -L
