# list all sections from the given markdown file
list-sections mdfile:
  grep -E '^#{2,4}' {{ mdfile }}
