#!/usr/bin/env bash
#
# check-skill-registration.sh
#
# Verifies that every `.agents/skills/premium-analytics-*.md` skill has a matching
# slash-command stub at `.claude/commands/<name>.md`. Catches the "Args from unknown
# skill" failure mode where a skill file is added but its command stub is forgotten,
# which surfaces only at invocation time with an unhelpful error.
#
# Scope is intentionally narrow (premium-analytics skills only). Other namespaces
# may opt in by extending the glob below — see `.agents/SKILL-NAMING.md`.
#
# Usage:
#   bash .agents/check-skill-registration.sh
#
# Exit codes:
#   0  — every in-scope skill has a stub
#   N  — N skills are missing their stubs (also printed by name)

set -euo pipefail

cd "$(git rev-parse --show-toplevel)"

missing=0

shopt -s nullglob
for skill in .agents/skills/premium-analytics-*.md; do
	name=$(basename "$skill" .md)
	stub=".claude/commands/${name}.md"
	if [ ! -f "$stub" ]; then
		echo "MISSING STUB: $stub (for $skill)"
		missing=$((missing + 1))
	fi
done
shopt -u nullglob

if [ "$missing" -eq 0 ]; then
	echo "OK: all premium-analytics skills have command stubs."
else
	echo ""
	echo "Found $missing skill(s) without a slash-command stub."
	echo "Each .agents/skills/premium-analytics-*.md must have a matching"
	echo ".claude/commands/<name>.md — see .agents/SKILL-NAMING.md."
fi

exit "$missing"
