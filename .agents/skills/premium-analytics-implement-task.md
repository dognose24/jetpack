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

## Step 1 — Resolve target branch

Read the branch name from the task md's Submitting section.

```bash
git fetch fork
CURRENT=$(git symbolic-ref --short HEAD 2>/dev/null || echo "")
if [ "$CURRENT" = "trunk" ] || [ -z "$CURRENT" ]; then
  # On trunk (or detached HEAD) — create the task's branch fresh from fork/trunk.
  git checkout -b <branch-name> fork/trunk
  TARGET_BRANCH=<branch-name>
else
  # Already on a feature branch — assume the caller wants to continue here
  # (e.g. bundling this task into an in-flight PR). Do not switch branches.
  echo "Continuing on existing branch: $CURRENT"
  TARGET_BRANCH=$CURRENT
fi
```

`TARGET_BRANCH` is the branch name to push and reference in later steps — it may
not equal `<branch-name>` from the task md when running in continue-on-branch mode.

The "continue on existing branch" mode is what lets a single PR bundle multiple
related changes — e.g. a docs commit on the same branch as the implementation.

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

## Step 5 — Execute additional Agent-verifiable DoD items

**Setup — always run, even if no DoD items apply this cycle.** Truncate any leftover
DoD-report buffer from a previous interrupted run, so Step 8 doesn't post stale
content. `cp /dev/null` is a portable single-command truncate using `cp` (already in
the skill's allow-list):

```bash
cp /dev/null /tmp/dod-report.md
```

This setup runs unconditionally, before the skip decision below — so even when this
cycle has no Agent-verifiable items beyond build + UI verification, the buffer is
guaranteed empty and Step 8's non-empty check stays silent.

Re-read the task md's `Definition of done` section. If there are no Agent-verifiable
items beyond the base build + UI verification (already covered by Steps 3–4), skip
the rest of this step.

For each remaining Agent-verifiable item, execute it (per the common pattern below
or task-specific instructions) **and then record the outcome** (required for every
item — see the Record outcome section after the pattern).

### Common pattern: local-only regression injection

The task spec defines a deliberate edit that should make a specific spec fail, then
asks for revert. The injection commonly targets the same file the implementation
already changed (e.g. swapping a mock-data label in `stage.tsx`), so a naive
`git checkout -- <file>` would discard the implementation along with the injection.

Use the git index as a baseline snapshot: stage the implementation first so the
revert is targeted to the injection only.

1. **Stage the implementation** so the index holds the work to preserve:
   ```bash
   git add <implementation-files>
   ```
2. Apply the injection edit (a small, scoped change to a file inside Scope) — it
   is now the only unstaged change in the tree.
3. Rebuild: `CI=true pnpm --filter='@automattic/jetpack-premium-analytics' build`.
4. Re-run `/premium-analytics-verify-ui`.
5. Confirm the expected spec fails (and that no other spec changes color).
6. **Revert the injection only**: `git checkout -- <file>` restores the file from
   the index, dropping the unstaged injection while keeping the staged
   implementation intact.
7. Rebuild and re-run `/premium-analytics-verify-ui`; the suite must be green again.

If the expected failure does not occur, treat the task as failed and stop —
the verification mechanism is not catching what the spec claims it catches.
Report the discrepancy and do not proceed to commit until the cause is understood.

### Record outcome — required for every Agent-verifiable item

This applies to **every** Agent-verifiable DoD item executed in Step 5, not only
the regression-injection pattern. After verifying the item, append a structured
block to `/tmp/dod-report.md` so Step 8 can post it as durable evidence:

```bash
cat >> /tmp/dod-report.md << 'EOF'
- **<one-line DoD item title from the task md>**: PASS
  - <one or more lines describing how the item was verified — fields vary by item>
EOF
```

For the regression-injection pattern specifically, fill in:
- Edit applied: `<e.g. 'Desktop' → 'Workstation' in routes/dashboard/stage.tsx>`
- Expected failing spec: `<spec-path:line and the assertion that should fail>`
- Actual failure: `<yes — paste the runner's failure-message excerpt>`
- Other specs: `<green throughout / which changed>`
- Revert + re-run: `<playwright summary, e.g. 4 passed (0 skipped)>`

For other Agent-verifiable items (deterministic CLI output, specific feature
behavior assertion, etc.), record the equivalent: what was checked, what the
expected outcome was, what was observed.

Do not commit `/tmp/dod-report.md` — `/tmp/` is outside the repo so this is
automatic.

## Step 6 — Changelog

Run the exact changelogger command from the task md's Submitting section:

```bash
pnpm jetpack changelogger add packages/premium-analytics \
  --significance=patch --type=added \
  --entry="<entry from task md>"
```

## Step 7 — Commit

Stage every scope-allowed file unconditionally — `git add` is idempotent, so files
already staged from Step 5's regression-injection pattern stay staged, and files
left unstaged by a non-regression DoD path (or by skipping Step 5 entirely) are
picked up. Then stage the changelog from Step 6 and commit:

```bash
git status                       # confirm no unstaged injection remains; verify the working tree matches Scope + changelog
git add <implementation-files>   # idempotent: stage anything in Scope not already in the index
git add <changelog-path>         # stage the changelog entry from Step 6
git commit -m "<conventional commit message>"
```

Do not stage or commit files outside the task's Scope section.

## Step 8 — Push and open or update PR

```bash
git push fork "$TARGET_BRANCH"
```

Use the `TARGET_BRANCH` captured in Step 1 — in continue-on-branch mode this may
differ from `<branch-name>` in the task md, and pushing the wrong ref will either fail
or publish stale work.

If no PR exists yet for this branch, open one against `dognose24/jetpack` trunk using
`/jetpack-pr`. If a PR is already open (continue-on-branch mode from Step 1), the push
updates it automatically — afterwards, update the PR title/description to cover the
new scope.

Fill or update the Agent Session Report section in the PR body:

```
## Agent Session Report
- Scope respected: yes / no
- Escalations triggered: N
- Contract violations: none / [describe]
- Human rework needed: none / minor / major
```

If Step 5 recorded any DoD outcomes (i.e. `/tmp/dod-report.md` is non-empty — the
setup in Step 5 truncates the file unconditionally, so a non-empty buffer is the
real signal that Step 5 ran items, distinct from "Step 5 was skipped this cycle"),
post them as a PR comment so reviewers can verify what was actually executed. The
post-revert filesystem state is identical whether Step 5 ran clean or was skipped,
so durable evidence is the only way to tell from the PR alone:

```bash
if [ -s /tmp/dod-report.md ]; then
  PR_NUM=$(gh pr view --json number -q .number)
  if {
    echo "## DoD verification"
    echo ""
    cat /tmp/dod-report.md
  } | gh pr comment "$PR_NUM" --body-file -; then
    # Only truncate after a successful post. `cp` is allow-list-friendly (no `rm` needed).
    cp /dev/null /tmp/dod-report.md
  else
    echo "ERROR: failed to post DoD verification comment for PR #$PR_NUM. Buffer preserved at /tmp/dod-report.md — retry the post or treat the task as failed per HARD rules; do not proceed to Step 9." >&2
    exit 1
  fi
fi
```

The truncate is gated on `gh pr comment` succeeding. If posting fails (auth /
network / PR doesn't exist / etc.), the buffer survives and the script exits
non-zero — required because the HARD rule below treats a missing `## DoD
verification` comment when Step 5 was in scope as task failure.

## Step 9 — Review cycle

`.github/workflows/pr-review-cycle.yml` fires on `pull_request: [opened, ready_for_review]`
(plus later review / comment / workflow_run events). It does **not** listen for
`pull_request.synchronize`, so it only auto-starts the kickoff round when the PR is
first opened or moved out of draft.

* **Brand-new PR** (trunk-branch case from Step 1) — the workflow kicks off
  automatically when the PR is opened.
* **Update-existing-PR / continue-on-branch mode** — a subsequent push to an
  already-open PR is `synchronize` and will not trigger a new round. Invoke manually:

  ```bash
  /jetpack-pr-review-cycle <PR-number>
  ```

Also fall back to manual invocation if the workflow is not configured for this repo
(e.g. missing `ANTHROPIC_API_KEY`) or if a workflow path filter excludes the PR's
changed files.

Keep the sandbox session alive (tmux recommended) so all rounds complete without
interruption.

## HARD rules

- Never touch files outside the task's Scope section.
- Never invent endpoints, stores, or data contracts.
- Never edit files in `build/`.
- Never merge or close the PR — that is always the human's call.
- If any step fails, stop and report the error. Do not skip steps.
- If Step 5 ran (task md DoD has Agent-verifiable items beyond build + UI verification), the PR **must** contain a `## DoD verification` comment posted in Step 8. The post-revert filesystem state is identical whether Step 5 ran clean or was silently skipped, so this comment is the only durable evidence the verification mechanism actually fired. Missing comment when Step 5 was in scope = treat the task as failed.
