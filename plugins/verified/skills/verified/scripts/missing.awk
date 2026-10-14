# Prints each token of tokenfile that deletedfile does not list and the remaining files (the rewrite) do not carry;
# exits 1 if any. Pass deletedfile before tokenfile, and both before the rewrite.
# A code span is found anywhere in the rewrite. Any other token only where it stands alone: no letter, digit or
# underscore touches it, no "." or "," comes before it, and no "." or "," followed by a digit comes after it, so
# "1 s" is not found in "0.1 s", nor "9.45.0" in "19.45.01", but "1 s," is found. A table cell's escaped bar (\|)
# counts as a bar, as tokens.awk prints it.

function word(c) { return c ~ /[0-9A-Za-z_]/ }

function found(t,    pos, at, b, a) {
  if (substr(t, 1, 1) == "`") return index(hay, t) > 0
  pos = 1
  while ((at = index(substr(hay, pos), t)) > 0) {
    at += pos - 1
    b = at > 1 ? substr(hay, at - 1, 1) : ""
    a = substr(hay, at + length(t), 1)
    if (!word(b) && b != "." && b != "," && !word(a) && !((a == "." || a == ",") && substr(hay, at + length(t) + 1, 1) ~ /[0-9]/))
      return 1
    pos = at + 1
  }
  return 0
}

FILENAME == deletedfile { deleted[$0] = 1; next }
FILENAME == tokenfile { if (!($0 in deleted)) tokens[++n] = $0; next }
{ line = $0; gsub(/\\\|/, "|", line); hay = hay line "\n" }
END {
  for (i = 1; i <= n; i++) if (!found(tokens[i])) { print tokens[i]; missing = 1 }
  exit missing + 0
}
