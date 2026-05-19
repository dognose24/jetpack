---
description: >
  Run a local-only regression injection against the wp-verify Playwright suite — stage
  the implementation as a baseline, apply the deliberate edit described in the task md's
  DoD section, rebuild, confirm the expected spec fails (and only that spec), revert
  via the git index, and confirm the suite returns green. Append a structured outcome
  block to /tmp/dod-report.md so the caller's evidence-persistence step can post it.
  Must run inside jetpack-ai-sandbox (Docker socket required for the build + verify
  loop).
argument-hint: <task-md-path>
allowed-tools: Bash(docker:*), Bash(pnpm:*), Bash(playwright:*), Bash(test:*), Bash(cat:*), Bash(cp:*), Bash(git add:*), Bash(git checkout:*), Bash(git diff:*), Bash(git status:*), Read
---

# regression-injection

Run a single regression-injection cycle for a task md whose Definition of Done
contains a regression-injection acceptance item. Uses the git index as a baseline
snapshot so the revert only drops the injection — not the implementation.

This skill is invoked by `/premium-analytics-implement-task` Step 5, and can also be
invoked standalone to re-verify an existing implementation's regression coverage
(e.g. during dogfood / audit).

## Input

Path to a task md. The DoD section must contain a regression-injection acceptance
item describing:

- **Edit applied**: which string/value in which file changes to what
- **Expected failing spec**: which `*.spec.ts` file should fail, and on what assertion
- **Revert + re-verify**: implicit — always required

The Scope section names the implementation files (used as the baseline-staging set).

## Pre-flight

```bash
test -f /.dockerenv || { echo "Run this skill inside jetpack-ai-sandbox"; exit 1; }
docker info > /dev/null 2>&1 || { echo "Docker socket not available — run wp-verify.sh up first"; exit 1; }
```

The caller (usually `/premium-analytics-implement-task` Step 4) is expected to have
already built + verified the implementation, so the working tree currently matches
the implementation. This skill does not re-run that initial verify.

## Step 1 — Stage implementation as baseline

Stage every file listed in the task md's Scope section that the implementation
touched:

```bash
git add <implementation-files>
```

This makes the index a "known good" snapshot. Step 5's `git checkout --` revert
restores from the index, dropping only the injection.

## Step 2 — Apply the injection

Apply the deliberate edit described in the task md's regression-injection acceptance
item. The edit must be scoped to files already in the task's Scope — never extend
reach beyond it.

After this, the injection should be the only unstaged change. Confirm:

```bash
git diff --name-only            # only the injected file(s) should appear
git diff --cached --name-only   # the implementation files
```

## Step 3 — Rebuild + verify

```bash
CI=true pnpm --filter='@automattic/jetpack-premium-analytics' build
playwright test --config tools/ai-sandbox/wp-verify/playwright.config.ts
```

Capture the runner's output — Step 6 needs the failure-message excerpt.

## Step 4 — Confirm expected failure isolation

Two assertions:

1. The expected failing spec (named in the task md) fails.
2. **All other specs remain green.** Cascade failures indicate the injection was
   too broad and the suite is no longer testing what the task md claims it tests.

If isolation fails — stop. Do not revert yet. Report the discrepancy: which other
specs failed, what the cascade source likely is. Cascade is a real signal,
not noise — the spec graph shares state in ways the task md didn't anticipate,
and the human needs to redesign the injection.

## Step 5 — Revert + reconfirm green

```bash
git checkout -- <injected-file>   # restores from index, drops the injection only
CI=true pnpm --filter='@automattic/jetpack-premium-analytics' build
playwright test --config tools/ai-sandbox/wp-verify/playwright.config.ts
```

The suite must be green again. If not — stop. The index baseline was contaminated
(e.g. an extra unstaged change crept in). Do not commit; investigate.

## Step 6 — Record outcome to /tmp/dod-report.md

Append a structured block for the caller's evidence-persistence step:

```bash
cat >> /tmp/dod-report.md << 'EOF'
- **<one-line DoD item title from task md>**: PASS
  - Edit applied: <e.g. 'Desktop' → 'Workstation' in routes/dashboard/stage.tsx>
  - Expected failing spec: <spec-path:line and assertion>
  - Actual failure: <runner's failure-message excerpt>
  - Other specs: green throughout
  - Revert + re-run: <playwright summary, e.g. 4 passed (0 skipped)>
EOF
```

The caller (typically `/premium-analytics-implement-task` Step 8) reads this file
and posts it as the `## DoD verification` PR comment. Do not commit
`/tmp/dod-report.md` — `/tmp/` is outside the repo, automatic.

## HARD rules

- Cascade failure in Step 4 → stop and report. Do not auto-narrow the injection;
  the human needs to know the spec graph isn't as isolated as the task md claimed.
- Suite not green in Step 5 → stop. Do not commit. The baseline was contaminated.
- Never extend the injection outside the task's Scope section.
- The caller is responsible for invoking `cp /dev/null /tmp/dod-report.md` at the
  start of its own flow (so a previous interrupted run's buffer doesn't leak into
  this run). This skill only appends.
