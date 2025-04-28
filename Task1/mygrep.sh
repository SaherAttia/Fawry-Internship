#!/usr/bin/env bash
# Tiny, case-insensitive grep clone.
# Options: -n  show line numbers
#          -v  invert match
#          -h / --help  usage

print_usage() {
cat <<EOF
Usage: $0 [OPTIONS] pattern file
Search (case-insensitive) for PATTERN inside FILE.

OPTIONS
  -n            Show line numbers for each matching line
  -v            Invert the match (print non-matching lines)
  -h, --help    Display this help and exit
EOF
}

# --------------------- --help (long option) ----------------------
for arg in "$@"; do
  [[ $arg == --help ]] && { print_usage; exit 0; }
done

# ------------------------- short options ------------------------
show_numbers=false
invert_match=false
while getopts ":nvh" opt; do
  case "$opt" in
    n) show_numbers=true ;;
    v) invert_match=true ;;
    h) print_usage; exit 0 ;;
    \?) echo "$0: invalid option -- '$OPTARG'" >&2
        print_usage; exit 1 ;;
  esac
done
shift $((OPTIND-1))          # drop parsed flags

# --------------------- positional-argument checks ----------------
case $# in
  0)  echo "$0: missing search string." >&2
      print_usage; exit 1 ;;
  1)  if [ -f "$1" ]; then
        echo "$0: missing search string." >&2
      else
        echo "$0: missing file operand after '$1'." >&2
      fi
      print_usage; exit 1 ;;
esac

pattern=$1
file=$2

if [ ! -f "$file" ]; then
  echo "$0: $file: No such file" >&2
  exit 1
fi

# --------------------------- main loop ---------------------------
shopt -s nocasematch        # case-insensitive [[ == ]]
lineno=0
while IFS= read -r line || [ -n "$line" ]; do
  ((lineno++))
  [[ $line == *"$pattern"* ]] && m=1 || m=0
  $invert_match && m=$((1-m))
  if [ $m -eq 1 ]; then
    $show_numbers && printf '%d:%s\n' "$lineno" "$line" \
                   || printf '%s\n' "$line"
  fi
done < "$file"
shopt -u nocasematch