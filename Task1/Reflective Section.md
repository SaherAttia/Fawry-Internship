# How the script handles arguments and options

1. Long option scan
- A short for loop looks for the literal string --help.
getopts has no built-in long-option support, so we handle this one
manually and exit immediately after printing the usage text.

2. Short-option parsing (getopts ":nvh")
- Valid switches are -n, -v, and -h.
- Each time getopts extracts an option, the case statement sets an
internal Boolean:
‑n → show_numbers=true
‑v → invert_match=true
‑h → show help and exit 0
- Any unknown flag falls through to \?, prints an error plus the
usage banner, then exits with status 1.

3. shift $((OPTIND-1))
- Removes every argument that has already been consumed by getopts,
so that $1 … now represent only positional parameters.

4. Positional-argument validation
- "$# == 0" → “missing search string.”
- "$# == 1" → We must decide which operand is missing:
– If the single token is an existing file (-f "$1" true)
→ the user supplied file only → complain that pattern is missing.
– otherwise the user supplied pattern only → complain that file is
missing and quote the pattern in the message.
In both cases we emit the usage text and exit 1.
- $# ≥ 2 → we’re good; store
pattern=$1 and file=$2.

5. Final file sanity check
- If the file doesn’t exist or isn’t a regular file, print a
“No such file” error and exit 1.

6. Main loop
- shopt -s nocasematch makes the [[ … == *"$pattern"* ]]
comparison case-insensitive without changing the pattern text.
For each line:
– test for a substring match → m=1 or m=0
– flip m if invert_match is true (-v).
– If m == 1, print the line; prepend the line number if
show_numbers is true.
- On EOF, shopt -u nocasematch restores the shell’s default.


# What would change to support regex or more grep-like options?
If we wanted to add full regular-expression support and extra options such as
-i (case-insensitive), -c (count only) and -l (list filenames), the code
would grow in two main areas:

**Option parsing:**
- Extend the getopts spec string to ":nviclh" (for example) and add
matching branches in the case block.
- Store additional Booleans: count_only, list_files, ignore_case
rather than the current implicit behaviour.

**Matching / output engine:**
- Replace the substring test
[[ $line == *"$pattern"* ]]
with a regex test
[[ $line =~ $pattern ]]
or call out to grep -E.
- For -i we would not enable nocasematch globally; instead we would
feed (?i)$pattern to [[ … =~ … ]] or use grep -i.
- -c would suppress per-line output and maintain a counter that is
printed once at the end.
- -l would break out of the loop after the first hit and print just the
filename (or combine with -c logic if both flags were present).

**The control flow would therefore split into three conceptual layers:**

- option/argument parsing
file/line iteration
“emit result” policy decided by the active flags (print line, count++, or
print filename and break).

# Hardest part to implement and why
- Surprisingly, it was the error-checking. After getopts strips the flags, Bash just leaves you with “how many” positional args are left, not “which is which.” When there’s exactly one arg we have to guess: is it the pattern or the file?
  
- I settled on a simple rule: if that single argument is a real file (-f "$1"), assume the user forgot the pattern; otherwise assume they forgot the file. It’s only a line of code, but arriving at that little heuristic (and making sure it didn’t misfire too often) took the most thought.
