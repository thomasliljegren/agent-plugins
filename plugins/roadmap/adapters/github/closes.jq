# The issue numbers a pull request body closes: GitHub's closing keywords, same repository only, in order, once each.
def closes:
  (. // "")
  | [match("\\b(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?):?\\s+#([0-9]+)"; "gi") | .captures[0].string | tonumber]
  | reduce .[] as $n ([]; if any(.[]; . == $n) then . else . + [$n] end);
