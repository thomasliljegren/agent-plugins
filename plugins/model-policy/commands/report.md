---
description: Summarise the subagent dispatches the model-policy hook has logged (by model, action, agent type and day)
allowed-tools: Bash(bash *)
---
Here is the model-policy log summary for the last 14 days:

!`bash "${CLAUDE_PLUGIN_ROOT}/scripts/report.sh" 14`

Relay the tables above to the user as they are, then say in two or three sentences whether the policy is doing anything: how many dispatches the hook filled or denied, and which model carries most of the subagent work. Do not speculate about token savings; the log records dispatches, not tokens.
