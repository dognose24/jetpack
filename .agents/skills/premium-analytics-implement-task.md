---
description: >
  Implement a premium-analytics task end-to-end: read the task md, create a branch from
  fork/trunk, implement, build, run UI verification, add a changelog entry, push, open a PR,
  and start the review cycle. Run inside jetpack-ai-sandbox (Docker socket required).
allowed-tools: Bash(docker:*), Bash(node:*), Bash(npx:*), Bash(playwright:*), Bash(npm:*), Bash(pnpm:*), Bash(bash:*), Bash(curl:*), Bash(sleep:*), Bash(test:*), Bash(mkdir:p), Bash(cat:*), Bash(cp:*), Bash(tr:*), Bash(sed:*), Bash(grep:*), Bash(git symbolic-ref:*), Bash(git rev-parse:*), Bash(git fetch:*), Bash(git checkout:*), Bash(git add:*), Bash(git diff:*), Bash(git commit:*), Bash(git push:*), Bash(git remote:*), Bash(git rm:*), Bash(git log:*), Bash(git status:*), Bash(gh pr create:*), Bash(gh pr view:*), Bash(gh pr comment:*), Bash(gh pr edit:*), Bash(gh api:*), Bash(mktemp:*), Write, Read
---

# premium-analytics Implement Task

Implement a premium-analytics task from a task md file through to an open PR with review
cycle started. Must run inside `jetpack-ai-sandbox` (Docker socket required for UI
verification).

## Input

The task md path is passed as the skill argument, e.g.:

```
/premium-analytics-implement-task projects/packages/premium-analytics/tasks/dashboard-line-chart.md
```

Read the task md fully before starting.

## Pre-flight

1. **Confirm inside sandbox:**
   ```bash
   test -f /.dockerenv || { echo "Run this skill inside jetpack-ai-sandbox"; exit 1; }
   ```

2. **Confirm Docker socket:**
   ```bash
   docker info > /dev/null 2>&1 || { echo "Docker socket not available — run wp-verify.sh up first"; exit 1; }
   ```

3. **Read the task md** and extract:
   - The branch name to create (from the Submitting section)
   - The changelog command
   - The scope (files allowed to touch)

## Step 1 — Create branch from fork/trunk

```bash
git fetch fork
git checkout -b <branch-name> fork/trunk
```

Use the exact branch name from the task md's Submitting section.

## Step 2 — Implement

Follow the Implementation section of the task md exactly:
- Only touch files listed in the Scope section
- Use mock data as specified — do not fetch, do not invent endpoints
- Do not modify anything in `build/`

## Step 3 — Build

```bash
CI=true pnpm --filter='@automattic/jetpack-premium-analytics' build
```

Build must succeed before proceeding. If it fails, fix the error and re-run.

## Step 4 — UI verification

```bash
/premium-analytics-verify-ui
```

If verification fails, fix the root cause and re-run from Step 3. Do not proceed until
verification passes.

## Step 5 — Changelog

Run the exact changelogger command from the task md's Submitting section:

```bash
pnpm jetpack changelogger add packages/premium-analytics \
  --significance=patch --type=added \
  --entry="<entry from task md>"
```

## Step 6 — Commit

```bash
git add -p   # stage only scope-allowed files + changelog
git commit -m "<conventional commit message>"
```

Do not stage or commit files outside the task's Scope section.

## Step 7 — Push and open PR

```bash
git push fork <branch-name>
```

Then open a PR against `dognose24/jetpack` trunk using `/jetpack-pr`. Fill the Agent
Session Report section in the PR body:

```
## Agent Session Report
- Scope respected: yes / no
- Escalations triggered: N
- Contract violations: none / [describe]
- Human rework needed: none / minor / major
```

## Step 8 — Start review cycle

Once the PR is open, start the review cycle:

```bash
/jetpack-pr-review-cycle <PR-number>
```

This runs in the foreground. Keep the sandbox session alive (tmux recommended) so all
review rounds complete without interruption.

## HARD rules

- Never touch files outside the task's Scope section.
- Never invent endpoints, stores, or data contracts.
- Never edit files in `build/`.
- Never merge or close the PR — that is always the human's call.
- If any step fails, stop and report the error. Do not skip steps.
