---
description: >
  Start the wp-verify WordPress environment, build premium-analytics, navigate to the
  Analytics admin page with Playwright, and assert the dashboard root mounts without uncaught
  JS exceptions. Use after any premium-analytics UI change as the agent-verifiable step in the
  Definition of Done. Requires the ai-sandbox with Docker socket mount and Playwright/Chromium
  installed.
allowed-tools: Bash(docker:*), Bash(node:*), Bash(npx:*), Bash(playwright:*), Bash(npm:*), Bash(pnpm:*), Bash(bash:*), Bash(curl:*), Bash(sleep:*), Bash(test:*), Bash(mkdir:*), Bash(cat:*), Write, Read
---

# premium-analytics UI Verification

Verify that the analytics dashboard mounts correctly in wp-admin after a premium-analytics build.

## Pre-flight

1. **Confirm Docker socket is accessible:**
   ```bash
   docker info > /dev/null 2>&1 || { echo "Docker socket not available — run inside jetpack-ai-sandbox"; exit 1; }
   ```

2. **Confirm Playwright is installed:**
   ```bash
   playwright --version > /dev/null 2>&1 || { echo "Playwright not found — rebuild sandbox image"; exit 1; }
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

```bash
NODE_PATH=$(npm root -g) node tools/ai-sandbox/wp-verify/check.cjs
```

Exit 0 = pass. Non-zero = the error message will indicate what failed.

## Step 4 — Commit screenshot

On success, copy the screenshot into the repo under a branch-named path and commit it:

```bash
BRANCH=$(git rev-parse --abbrev-ref HEAD | tr '/' '-')
SCREENSHOT_DEST="docs/screenshots/${BRANCH}.png"
mkdir -p docs/screenshots
cp /tmp/pa-verify/analytics-dashboard.png "$SCREENSHOT_DEST"
git add "$SCREENSHOT_DEST"
git commit -m "chore: add wp-verify screenshot for ${BRANCH}"
```

The committed screenshot is then referenceable in the PR description:

```markdown
## Screenshot

![Analytics dashboard](docs/screenshots/<branch-name>.png)
```

Replace `<branch-name>` with the actual branch name when writing the PR body.

## Step 5 — Report result

On success:
- Log: `✓ Analytics dashboard mounted without uncaught JS exceptions`
- The screenshot is committed and visible in the PR description

On failure:
- Log the full error
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
