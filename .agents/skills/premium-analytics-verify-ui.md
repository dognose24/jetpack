---
description: >
  Start the wp-verify WordPress environment, build premium-analytics, navigate to the
  Analytics admin page with Playwright, and assert the dashboard root mounts without console
  errors. Use after any premium-analytics UI change as the agent-verifiable step in the
  Definition of Done. Requires the ai-sandbox with Docker socket mount and Playwright/Chromium
  installed.
allowed-tools: Bash(docker:*), Bash(node:*), Bash(npx:*), Bash(playwright:*), Bash(npm:*), Bash(pnpm:*), Bash(curl:*), Bash(sleep:*), Bash(test:*), Bash(mkdir:*), Bash(cat:*), Write, Read
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
# Detect the host-side path of the jetpack repo.
# docker compose runs via the host Docker socket; the daemon resolves bind-mount
# paths against the HOST filesystem, not the sandbox — so we must pass the host path.
JETPACK_HOST_PATH=$(docker inspect jetpack-ai-sandbox \
  --format '{{range .Mounts}}{{if eq .Destination "/home/dev/jetpack"}}{{.Source}}{{end}}{{end}}')
[ -z "$JETPACK_HOST_PATH" ] && { echo "Could not detect host jetpack path — is the container named jetpack-ai-sandbox?"; exit 1; }
export JETPACK_HOST_PATH

BASE_FILE=tools/ai-sandbox/docker-compose.yml
OVERRIDE_FILE=tools/ai-sandbox/docker-compose.wp-verify.yml
COMPOSE_ARGS="-f $BASE_FILE -f $OVERRIDE_FILE --project-directory tools/ai-sandbox --profile wp-verify"

# Name services explicitly to avoid accidentally starting/modifying jetpack-ai itself.
docker compose $COMPOSE_ARGS up -d mysql wordpress wpcli

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

Write and execute a one-shot Playwright script:

```bash
mkdir -p /tmp/pa-verify

cat > /tmp/pa-verify/check.cjs << 'EOF'
// CommonJS so NODE_PATH is honoured when resolving the globally-installed playwright package.
// Wrapped in an async IIFE because top-level await is not valid in CommonJS.
const { chromium } = require('playwright');

(async () => {
  const WP_BASE = 'http://wordpress';
  const ANALYTICS_URL = `${WP_BASE}/wp-admin/admin.php?page=jetpack-premium-analytics`;

  const browser = await chromium.launch({ args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  const page = await browser.newPage();
  const errors = [];

  page.on('pageerror', err => errors.push(err.message));
  page.on('console', msg => {
    if (msg.type() === 'error') errors.push(msg.text());
  });

  // Login
  await page.goto(`${WP_BASE}/wp-login.php`);
  await page.fill('#user_login', 'admin');
  await page.fill('#user_pass', 'password');
  await page.click('#wp-submit');
  await page.waitForURL('**/wp-admin/**');

  // Navigate to Analytics
  await page.goto(ANALYTICS_URL);

  // Wait for React to mount — the dashboard root div should appear
  await page.waitForSelector('.jetpack-premium-analytics-dashboard', { timeout: 15000 })
    .catch(() => { throw new Error('Dashboard root not found — React may not have mounted'); });

  // Assert the dashboard heading rendered
  const heading = await page.$eval(
    '.jetpack-premium-analytics-dashboard h1',
    el => el.textContent.trim()
  ).catch(() => { throw new Error('Dashboard h1 not found — React may not have rendered'); });
  if (heading !== 'Analytics') {
    throw new Error(`Unexpected dashboard heading: "${heading}"`);
  }

  // Screenshot for the PR
  await page.screenshot({ path: '/tmp/pa-verify/analytics-dashboard.png', fullPage: false });

  await browser.close();

  if (errors.length) {
    console.error('Console errors detected:\n' + errors.join('\n'));
    process.exit(1);
  }

  console.log('✓ Analytics dashboard mounted without errors');
  console.log('Screenshot saved to /tmp/pa-verify/analytics-dashboard.png');
})();
EOF

NODE_PATH=$(npm root -g) node /tmp/pa-verify/check.cjs
```

If the script exits 0, verification passes. If it exits non-zero, the error message will indicate what failed.

## Step 4 — Report result

On success:
- Log: `UI verification passed — Analytics dashboard mounted`
- Attach screenshot path to the PR comment if running inside `jetpack-pr-review-cycle`

On failure:
- Log the full error
- Do NOT mark the Definition of Done as complete
- Fix the root cause and re-run from Step 3 (WordPress stays up between runs)

## Teardown (optional)

Leave WordPress running during the review cycle so subsequent verification rounds skip Step 1–2. Tear down only at the end of the cycle or when explicitly requested:

```bash
docker compose \
  -f tools/ai-sandbox/docker-compose.yml \
  -f tools/ai-sandbox/docker-compose.wp-verify.yml \
  --project-directory tools/ai-sandbox \
  --profile wp-verify \
  down
```

## HARD rules

- Never run this skill outside the `jetpack-ai-sandbox` container — the Docker socket gives host-level access.
- Never commit `/tmp/pa-verify/` contents.
- The admin credentials (`admin` / `password`) are for the throwaway test environment only — do not reuse elsewhere.
