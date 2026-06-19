#!/usr/bin/env bash

# List all .md files from rfcs subfolders into an array
md_files=( )
for dir in rfcs/*/; do
  for file in "$dir"*.md; do
    if [ -f "$file" ]; then
      md_files+=("$file")
    fi
  done
done

counter=0

# Extract all possible status values from the RFC template and save them into an array
status_line=$(grep "^\- \*\*Status:\*\*" templates/rfc-template.md)
status_values=$(echo "$status_line" | sed -E 's/.*Status:\*\* (.*)/\1/')
IFS='|' read -ra status_array <<< "$status_values"
for i in "${!status_array[@]}"; do
  status_array[$i]="$(echo "${status_array[$i]}" | xargs)" # Trim whitespace from each status
done
status_regex=$(IFS='|'; echo "${status_array[*]}") # Join status_array into a regex alternation string
printf '[PossibleStatus regex]\n%s\n' "$status_regex"

# Print the array
printf '\n[Found files]\n'
printf ' - %s\n' "${md_files[@]}"

# Check if the first line of each file matches the required title pattern
printf '\n[Checking RFC headers - titles]\n'
for file in "${md_files[@]}"; do
  first_line=$(head -n 1 "$file")
  if [[ $first_line =~ ^#\ RFC-[0-9]{4}:\ [A-Za-z0-9]{2,}.*$ ]]; then
    echo " OK: $file"
  else
    # Print in red if missing or invalid
    echo -e "\033[31m INVALID RFC HEADER: $file\033[0m"
    echo -e "\033[31m  Expected format:    # RFC-XXXX: Title\033[0m"
    echo -e "\033[31m  Found:              $first_line\033[0m"
    counter=$((counter + 1))
  fi
done

# Check if the 2nd line of each file is empty
printf '\n[Checking RFC headers - space between title and the metadata]\n'
for file in "${md_files[@]}"; do
  second_line=$(head -n 2 "$file" | tail -n 1)
  if [[ -z $second_line ]]; then
    echo " OK: $file"
  else
    # Print in red if missing or invalid
    echo -e "\033[31mNO EMPTY LINE AFTER THE TITLE: $file\033[0m"
    counter=$((counter + 1))
  fi
done

# Check the header metadata for each file
printf '\n[Checking RFC headers - metadata]'
for file in "${md_files[@]}"; do
  first_line=$(sed -n '1p' "$file")
  rfc_number=$(sed -n '3p' "$file")
  title=$(sed -n '4p' "$file")
  status=$(sed -n '5p' "$file")
  authors=$(sed -n '6p' "$file")
  created=$(sed -n '7p' "$file")
  updated=$(sed -n '8p' "$file")
  version=$(sed -n '9p' "$file")
  supersedes=$(sed -n '10p' "$file")
  related_links=$(sed -n '11p' "$file")
  valid=true


  # Extract the RFC number and title from the first line
  if [[ $first_line =~ ^#\ RFC-([0-9]{4}):\ (.+)$ ]]; then
    first_line_rfc_number="${BASH_REMATCH[1]}"
    first_line_rfc_title="${BASH_REMATCH[2]}"
    # Optionally print or use these variables
    # echo "RFC Number: $rfc_number"
    # echo "RFC Title: $rfc_title"
  fi

  echo -e "\n File metadata: $file"

  # Check if the RFC Number in metadata matches the one in the first line
  if [[ "$rfc_number" != "- **RFC Number:** $first_line_rfc_number" ]]; then
    echo -e "\033[31m  RFC NUMBER MISMATCH\033[0m"
    valid=false
    counter=$((counter + 1))
  fi

  # Check if the RFC Title in metadata matches the one in the first line
  if [[ "$title" != "- **Title:** $first_line_rfc_title" ]]; then
    echo -e "\033[31m  RFC TITLE MISMATCH\033[0m"
    valid=false
    counter=$((counter + 1))
  fi

  # Check if the RFC Status in metadata is valid using the generated regex
  if [[ ! "$status" =~ ^-\ \*\*Status:\*\*\ ($status_regex)$ ]]; then
    echo -e "\033[31m  RFC STATUS INVALID\033[0m"
    valid=false
    counter=$((counter + 1))
  fi

  # Check if the RFC Authors in metadata is valid (any character after prefix)
  if [[ ! $authors =~ ^-\ \*\*Author\(s\):\*\*\ .+ ]]; then
    echo -e "\033[31m  RFC AUTHORS INVALID\033[0m"
    valid=false
    counter=$((counter + 1))
  fi

  # Check if the RFC Created in metadata is valid (YYYY-MM-DD)
  if [[ ! $created =~ ^-\ \*\*Created:\*\*\ [0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then

    if [[ $created == "- **Created:** YYYY-MM-DD" ]]; then
      echo -e "\033[31m  RFC CREATED DATE NOT FILLED\033[0m"
    else
      echo -e "\033[31m  RFC CREATED INVALID\033[0m"
    fi

    valid=false
    counter=$((counter + 1))
  fi

  # Check if the RFC Updated in metadata is valid (YYYY-MM-DD)
  if [[ ! $updated =~ ^-\ \*\*Updated:\*\*\ [0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    if [[ $updated == "- **Updated:** YYYY-MM-DD" ]]; then
      echo -e "\033[31m  RFC UPDATED DATE NOT FILLED\033[0m"
    else
      echo -e "\033[31m  RFC UPDATED INVALID\033[0m"
    fi
    valid=false
    counter=$((counter + 1))
  fi

  # Check if the RFC Version in metadata is valid (vX.X.X, optional space, optional status)
  if [[ ! $version =~ ^-\ \*\*Version:\*\*\ v[0-9]+\.[0-9]+\.[0-9]+(\ \((($status_regex))\))?$ ]]; then
    echo -e "\033[31m  RFC VERSION INVALID\033[0m"
    valid=false
    counter=$((counter + 1))
  fi

  # Check if the RFC Supersedes in metadata is valid (any character after prefix)
  if [[ ! $supersedes =~ ^-\ \*\*Supersedes:\*\*\ .+ ]]; then
    echo -e "\033[31m  RFC SUPERSEDES INVALID\033[0m"
    valid=false
    counter=$((counter + 1))
  fi

  # Check if the RFC Related Links in metadata is valid (any character after prefix)
  if [[ ! $related_links =~ ^-\ \*\*Related\ Links:\*\*\ .+ ]]; then
    echo -e "\033[31m  RFC RELATED LINKS INVALID\033[0m"
    valid=false
    counter=$((counter + 1))
  fi

  if [ "$valid" = true ]; then
    echo "  All OK"
  fi
done

if [ $counter -eq 0 ]; then
  printf '\033[38;5;28m\n[No issues found]\033[0m\n'
else
  printf "\033[31m\n[Total issues found: %d]\n\033[0m" "$counter"
  exit 1
fi