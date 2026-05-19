---
description: >
  Start the wp-verify WordPress environment, build premium-analytics, navigate to the
  Analytics admin page with Playwright, and assert the dashboard root mounts without uncaught
  JS exceptions. Use after any premium-analytics UI change as the agent-verifiable step in the
  Definition of Done. Requires the ai-sandbox with Docker socket mount and Playwright/Chromium
  installed.
allowed-tools: Bash(docker:*), Bash(node:*), Bash(npx:*), Bash(playwright:*), Bash(npm:*), Bash(pnpm:*), Bash(bash:*), Bash(curl:*), Bash(sleep:*), Bash(test:*), Bash(mkdir:*), Bash(cat:*), Bash(cp:*), Bash(tr:*), Bash(sed:*), Bash(grep:*), Bash(git symbolic-ref:*), Bash(git rev-parse:*), Bash(git add:*), Bash(git diff:*), Bash(git commit:*), Bash(git remote:*), Bash(git rm:*), Write, Read
---

# premium-analytics UI Verification

Verify that the analytics dashboard mounts correctly in wp-admin after a premium-analytics build.

## Pre-flight

1. **Confirm Docker socket is accessible:**
   ```bash
   docker info > /dev/null 2>&1 || { echo "Docker socket not available — run inside jetpack-ai-sandbox"; exit 1; }
   ```

2. **Confirm Playwright Test runner is installed:**
   ```bash
   command -v playwright > /dev/null 2>&1 || { echo "playwright binary not found on PATH — rebuild sandbox image: docker compose -f tools/ai-sandbox/docker-compose.yml build jetpack-ai"; exit 1; }
   playwright test --version > /dev/null 2>&1 || { echo "@playwright/test runner not available — rebuild sandbox image: docker compose -f tools/ai-sandbox/docker-compose.yml build jetpack-ai"; exit 1; }
   ```

3. **Confirm build artifacts exist:**
   ```bash
   test -f projects/packages/premium-analytics/build/build.php || {
     echo "Build artifacts missing — run: pnpm --filter=@automattic/jetpack-premium-analytics build"
     exit 1
   }
   ```
   If missing, build first:
   ```bash
   CI=true pnpm --filter='@automattic/jetpack-premium-analytics' build
   ```

## Step 1 — Start WordPress environment

```bash
# wp-verify.sh auto-detects JETPACK_HOST_PATH and starts the full stack.
# Works from the repo root on the host, or from inside jetpack-ai-sandbox.
bash tools/ai-sandbox/wp-verify.sh up

# Convenience variables for subsequent compose exec calls.
JETPACK_HOST_PATH=$(docker inspect jetpack-ai-sandbox \
  --format '{{range .Mounts}}{{if eq .Destination "/home/dev/jetpack"}}{{.Source}}{{end}}{{end}}')
export JETPACK_HOST_PATH
COMPOSE_ARGS="-f tools/ai-sandbox/docker-compose.yml -f tools/ai-sandbox/docker-compose.wp-verify.yml --project-directory tools/ai-sandbox --profile wp-verify"

echo "Waiting for WordPress to be ready..."
TRIES=0
until docker compose $COMPOSE_ARGS exec -T wordpress curl -sf http://localhost/wp-login.php > /dev/null 2>&1; do
  TRIES=$((TRIES + 1))
  [ $TRIES -gt 30 ] && echo "WordPress did not start in time" && exit 1
  sleep 5
done
echo "WordPress is up."
```

## Step 2 — Wait for wpcli setup to complete

The `wpcli` container runs `wp core install` and `wp plugin activate gutenberg` on startup.
Wait for it to finish before proceeding (the container reaches `sleep infinity` only after
successful setup):

```bash
echo "Waiting for wpcli setup to complete..."
TRIES=0
until docker compose $COMPOSE_ARGS exec -T wpcli wp core is-installed --allow-root 2>/dev/null; do
  TRIES=$((TRIES + 1))
  [ $TRIES -gt 20 ] && echo "wpcli setup did not complete in time" && exit 1
  sleep 5
done
echo "wpcli setup complete."
```

## Step 3 — Run Playwright verification

Run the Playwright Test suite against the wp-verify environment:

```bash
NODE_PATH=$(npm root -g) playwright test --config tools/ai-sandbox/wp-verify/playwright.config.ts
```

`NODE_PATH=$(npm root -g)` is required because the sandbox image installs
`@playwright/test` globally; without it, the config file's
`import { defineConfig } from '@playwright/test'` in
`tools/ai-sandbox/wp-verify/playwright.config.ts` fails to resolve, since
standard Node module resolution from that file doesn't reach the global path.

The suite lives under `tools/ai-sandbox/wp-verify/tests/`:

- `dashboard-mount.spec.ts` — mount + heading, height-bounded, no zero-height SVG
- `pie-chart-tooltip.spec.ts` — skipped until a pie chart is rendered on the dashboard

The mount spec also writes a fresh screenshot to `/tmp/pa-verify/analytics-dashboard.png`,
which Step 4 commits.

Exit 0 = all specs passed (skipped counts as passed). Non-zero = the runner's terminal
output names the failing spec(s); rerun a single failing one with
`NODE_PATH=$(npm root -g) playwright test --config tools/ai-sandbox/wp-verify/playwright.config.ts <spec-name>`
to iterate.

The legacy `node tools/ai-sandbox/wp-verify/check.cjs` script is **deprecated** and kept
only as a temporary fallback. Do not invoke it for normal verification.

## Step 4 — Commit screenshot

On success, commit the screenshot and print a Markdown image snippet to embed in the PR description:

```bash
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null | tr '/' '-')
[ -z "$BRANCH" ] && { echo "Detached HEAD — run from a named branch"; exit 1; }
SCREENSHOT_DEST="docs/screenshots/${BRANCH}.png"
mkdir -p docs/screenshots
test -f /tmp/pa-verify/analytics-dashboard.png || { echo "Screenshot not found — re-run Step 3"; exit 1; }
cp /tmp/pa-verify/analytics-dashboard.png "$SCREENSHOT_DEST"
git add "$SCREENSHOT_DEST"
git diff --cached --quiet -- "$SCREENSHOT_DEST" || \
  git commit -m "chore: add wp-verify screenshot for ${BRANCH}" -- "$SCREENSHOT_DEST" || exit 1
git remote | grep -q '^fork$' && REMOTE=fork || REMOTE=origin
REPO=$(git remote get-url "$REMOTE" \
  | sed 's/.*github\.com[:/]\(.*\)\.git$/\1/' \
  | sed 's/.*github\.com[:/]\(.*\)$/\1/')
echo "$REPO" | grep -qE '^[^/]+/[^/]+$' || { echo "Could not derive repo slug from remote — check: git remote get-url $REMOTE"; exit 1; }
COMMIT=$(git rev-parse HEAD)
echo "![Analytics dashboard](https://raw.githubusercontent.com/${REPO}/${COMMIT}/docs/screenshots/${BRANCH}.png)"
```

Push the branch before pasting this URL into the PR description — the raw URL resolves
only after the commit is on the remote. The URL is pinned to the commit SHA so the image
reference remains stable as the branch grows. If the branch history is later rewritten
(rebase or force-push), re-run Step 4 and update the PR description link.

**Before merge:** remove the screenshot file so it is absent from the final tree:

```bash
BRANCH=$(git symbolic-ref --short HEAD 2>/dev/null | tr '/' '-')
[ -z "$BRANCH" ] && { echo "Detached HEAD — run from a named branch"; exit 1; }
git rm --ignore-unmatch "docs/screenshots/${BRANCH}.png"
git diff --cached --quiet -- "docs/screenshots/${BRANCH}.png" || \
  git commit -m "chore: remove wp-verify screenshot before merge" -- "docs/screenshots/${BRANCH}.png"
```

After the removal commit, a squash-merge produces a single commit that reflects the
final tree — which no longer contains the PNG. The raw URL remains reachable while
GitHub retains the object, long enough for reviewers.

## Step 5 — Report result

On success:
- `playwright test` exits 0 and prints a summary like `2 passed (2 skipped)` on a chartless dashboard — the zero-height-SVG test skips when no charts are present, and the `pie-chart-tooltip` spec is skipped until that task lands
- The screenshot is committed and visible in the PR description

On failure:
- `playwright test` exits non-zero; the list reporter names the failing spec
- For deeper inspection (trace, video, full-page screenshot of the failure), look in `/tmp/pa-verify/playwright-output/` — the config retains trace and video on failure
- Do NOT mark the Definition of Done as complete
- Fix the root cause and re-run from Step 3 (WordPress stays up between runs)

## Teardown (optional)

Leave WordPress running during the review cycle so subsequent verification rounds skip Step 1–2. Tear down only at the end of the cycle or when explicitly requested:

```bash
bash tools/ai-sandbox/wp-verify.sh down
```

Safe to run from inside `jetpack-ai-sandbox` — when in-container the script only stops the WP services (mysql, wordpress, wpcli) and does not touch the sandbox container itself.

## HARD rules

- Never run this skill outside the `jetpack-ai-sandbox` container — the Docker socket gives host-level access.
- Never commit `/tmp/pa-verify/` contents.
- The admin credentials (`admin` / `password`) are for the throwaway test environment only — do not reuse elsewhere.
