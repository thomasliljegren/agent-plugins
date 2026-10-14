# The tokens of a Markdown file that a rewrite must carry across unchanged, one per line: each line of fenced code,
# trimmed; each code span, with its backticks; commit hashes; versions; numbers with a unit, a range counting as one.
# A table cell's escaped bar (\|) is printed as a bar, so a row rewritten as a bullet keeps its tokens.
# POSIX awk only (BSD awk, mawk): no interval expressions, so lengths and boundaries are checked by hand.

function word(c) { return c ~ /[0-9A-Za-z_]/ }
function before(s, start) { return start > 1 ? substr(s, start - 1, 1) : "" }

# A code span opens with a run of backticks and closes at the next run of exactly as many (CommonMark), so
# ``Nullable`1`` is one span. An opening run that never closes is literal backticks.
function spans(s,    pos, start, n, end, t) {
  pos = 1
  while (match(substr(s, pos), /`+/)) {
    start = pos + RSTART - 1
    n = RLENGTH
    pos = start + n
    end = 0
    while (match(substr(s, pos), /`+/)) {
      if (RLENGTH == n) { end = pos + RSTART - 1; break }
      pos += RSTART - 1 + RLENGTH
    }
    if (end) {
      t = substr(s, start, end + n - start)
      gsub(/\\\|/, "|", t)
      print t
      pos = end + n
    } else pos = start + n
  }
}

function hashes(s,    pos, start, t) {
  pos = 1
  while (match(substr(s, pos), /[0-9a-f]+/)) {
    start = pos + RSTART - 1
    t = substr(s, start, RLENGTH)
    if (length(t) >= 7 && length(t) <= 40 && t ~ /[0-9]/ && !word(before(s, start)) && !word(substr(s, start + RLENGTH, 1)))
      print t
    pos = start + RLENGTH
  }
}

function versions(s,    pos, start, b) {
  pos = 1
  while (match(substr(s, pos), /[0-9]+\.[0-9]+\.[0-9]+/)) {
    start = pos + RSTART - 1
    b = before(s, start)
    if (!word(b) && b != "." && !word(substr(s, start + RLENGTH, 1)))
      print substr(s, start, RLENGTH)
    pos = start + RLENGTH
  }
}

# A number is digits with "." or "," inside, or groups of three after a space ("65 000"); a range ("4.9 to 5.1 s")
# is one measure. A count followed by a word that starts like a unit ("3 starts") is no measure: the character after
# the unit must end the word. The scan moves one character on after each match, so "3 starts 5 ms" still finds
# "5 ms" and a range's upper bound is a measure of its own; the tail of a number in groups ("000 characters") is not.
function measures(s,    pos, start, b) {
  pos = 1
  while (match(substr(s, pos), /[0-9][0-9.,]*( [0-9][0-9][0-9])*(( to | – |–|-)[0-9][0-9.,]*( [0-9][0-9][0-9])*)?[ ]?(ns|µs|ms|s|seconds|min|minutes|h|hours|lines|characters|connections|tests|MB|GB|%)/)) {
    start = pos + RSTART - 1
    b = before(s, start)
    if (!word(b) && b != "." && b != "," && !word(substr(s, start + RLENGTH, 1)) \
        && !(b == " " && before(s, start - 1) ~ /[0-9]/ && substr(s, start, 4) ~ /^[0-9][0-9][0-9][^0-9.,]/))
      print substr(s, start, RLENGTH)
    pos = start + 1
  }
}

/^[ \t]*(```|~~~)/ { fenced = !fenced; next }
fenced {
  line = $0
  sub(/^[ \t]+/, "", line)
  sub(/[ \t]+$/, "", line)
  if (line != "") print line
  next
}
{ spans($0); hashes($0); versions($0); measures($0) }
