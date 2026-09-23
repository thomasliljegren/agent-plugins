#!/usr/bin/env bash
# Prints the effective tier map (bundled defaults plus your override) as markdown tables.
# Run: bash scripts/defaults-table.sh [tiers|agent-types]
set -u
HERE=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
. "$HERE/lib/config.sh"
CONFIG=$(model_policy_config) || { echo "cannot read config/models.json" >&2; exit 1; }
case "${1:-tiers}" in
  tiers)
    jq -r '
      "| Harness | fast | standard | strong | frontier |",
      "|---|---|---|---|---|",
      (.harnesses | to_entries[]
        | "| \(.key) | " + ([.value.tiers[("fast", "standard", "strong", "frontier")].default | "`\(.)`"] | join(" | ")) + " |")' <<<"$CONFIG"
    ;;
  agent-types)
    jq -r '
      "| Harness | Agent type | Tier |",
      "|---|---|---|",
      (.harnesses | to_entries[] | .key as $h | .value.agentTypes | to_entries[]
        | "| \($h) | `\(.key)` | \(.value) |")' <<<"$CONFIG"
    ;;
  *)
    echo "usage: defaults-table.sh [tiers|agent-types]" >&2
    exit 2
    ;;
esac
