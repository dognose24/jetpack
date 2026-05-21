# AGENTS.md — premium-analytics

This file is authoritative. Read it fully before making any changes.

---

## What this package is

A full-page SPA rendered inside `wp-admin`. Boot chain:

1. `src/class-analytics.php` — PHP entry, registers admin page and enqueues build output
2. `build/build.php` (generated) — registers boot and interceptor behavior
3. `@wordpress/boot` — provides the full-page shell
4. Routes discovered from `route` metadata in each `routes/*/package.json`, lazy-loaded

**Do not break this chain.**

---

## Current file structure

```
src/class-analytics.php        PHP entry point
shims/boot-asset.php           compatibility shim — DO NOT remove
packages/init/src/index.ts     boot-time initialization (icon, menu state)
routes/dashboard/              the only route so far
  package.json                 route metadata
  stage.tsx                    route component
build/                         generated — never edit manually
```

---

## Allowed without approval

- Add or modify routes under `routes/**`
- Edit `routes/**/stage.tsx`
- Edit `packages/init/**`
- Edit `src/class-analytics.php` while preserving the page boot contract
- Add docs, tests, non-generated source files
- Refine copy and localization strings
- Consuming **existing** Jetpack REST endpoints via `@wordpress/api-fetch` in route components or `packages/` modules
- Creating new data packages under `packages/` that only consume existing endpoints (no new PHP contracts)

---

## Requires human approval

- Changing page id `jetpack-premium-analytics`
- Changing admin page slug `jetpack-premium-analytics`
- Removing or modifying the shim copy step in build scripts
- Removing or bypassing `packages/init/`
- Changing `@wordpress/build`, `@wordpress/boot`, or `@wordpress/route` versions
- Introducing **new** backend REST endpoints or data contracts (new PHP routes, new XMLRPC methods)
- Introducing new `@wordpress/data` stores that are shared across routes or packages
- Modifying cross-package or monorepo-wide build behavior

---

## Phased data work

The dashboard is being built in two phases:

- **Phase 1**: UI-only, hardcoded mock data. No data fetching is permitted.
  Individual chart / settings tasks are tracked in Linear, not as task md
  files in this repo (see "Linear issue contract" section below).
- **Phase 2** (task not yet written): Consume `GET /jetpack/v4/stats/blog`
  (already registered by `projects/packages/stats/`).
  Route-local `useStats()` hook via `@wordpress/api-fetch` is allowed.
  Do not register new endpoints or shared stores without approval.

**Boundary rule:** "existing endpoint" means the route is already registered in PHP
and documented in `projects/packages/stats/`. Calling an undocumented or new path
requires human approval.

---

## Never do

- Edit anything inside `build/`
- Invent endpoints, stores, selectors, event models, metrics, or feature flags
- Write UI copy that implies analytics data or premium features exist when they do not

---

## Adding a route

@docs/add-route.md

---

## Definition of done

**Agent-verifiable (required before push):**
- [ ] Build succeeds
- [ ] UI verification passes: run `/premium-analytics-verify-ui` inside `jetpack-ai-sandbox` and confirm the Analytics dashboard mounts without uncaught JS exceptions

**Human-verifiable (PR review):**
- [ ] Route navigation works
- [ ] No shim-dependent regression

---

## After opening a PR

The `.github/workflows/pr-review-cycle.yml` workflow runs review cycle rounds automatically —
no manual trigger needed when `ANTHROPIC_API_KEY` is configured as a repo secret.
Automatic runs only apply to same-repo, non-draft PR branches; fork PRs and draft
PRs are skipped. Draft PRs trigger once marked ready for review.

If the workflow is not available or you need to run a round manually:

```bash
/jetpack-pr-review-cycle
```

---

## PR review workflow

When asked to address PR feedback, fetch unresolved comments directly — do not wait for the user to paste them:

```bash
gh api repos/Automattic/jetpack/pulls/<PR>/comments
gh api repos/Automattic/jetpack/pulls/<PR>/reviews
```

Address all open comments, commit, and push. Then leave a summary comment on the PR listing what was changed.

---

## Stop and ask a human when

- Unsure whether a change affects boot sequence, route discovery, or admin page registration
- Any change to page identity, slug, or `@wordpress/boot` assumptions
- Introducing data fetching that targets an endpoint NOT listed in `projects/packages/stats/`
- Introducing a `@wordpress/data` store shared across more than one route
- Any persistence, write operations, or analytics event tracking

---

## Common patterns and pitfalls

Invariants discovered through implementation that the next agent should
know up front, so individual task issues don't re-explain the rationale.

### `@automattic/charts` usage

- **Use `*Unresponsive` chart variants** (`PieChartUnresponsive`,
  `LineChartUnresponsive`, etc.) when the parent container does not have
  a fixed height. The responsive wrappers use `withResponsive` +
  `useParentSize` to measure their parent, which feedback-loops with
  `ChartLayout`'s internal `ResizeObserver` and causes infinite vertical
  growth.

- **`withTooltips` prop is required** if hover/tooltip Playwright specs
  are part of the task's DoD. Without it the chart skips its mouse
  handlers, the tooltip portal never renders, and any spec that hovers
  + asserts on `.visx-tooltip` content (e.g.
  `expect(tooltip).toBeVisible()`) fails because the element it's
  waiting for never appears.

- **CSS subpath import is required**: `import '@automattic/charts/style.css';`
  must be present in the route that renders the chart. The package does
  not auto-inject styles. Without it, `ChartLayout`'s `ResizeObserver`
  measures inline-SVG descender space and the chart height drifts
  upward on each cycle.

- **The CSS import needs an `eslint-disable` directive — and both
  forms have been observed to disappear during pre-commit
  `lint-file --fix`.** Use either inline (`eslint-disable-line`) or
  next-line (`eslint-disable-next-line`); after `git commit`, run
  `git show HEAD -- <file>` and confirm the comment is still on the
  import. If missing, re-add it in a follow-up commit. See "ESLint
  patterns" below for details; the 5-round forensic trail lives in
  [`docs/research/eslint-disable-line-discovery.md`](docs/research/eslint-disable-line-discovery.md).

### ESLint patterns

`@automattic/charts/style.css` is a subpath export that resolves to
`dist/index.css`, which is gitignored and not built during the ESLint CI
step, so `import/no-unresolved` fires on the import. The standard fix is
to disable that rule for the line:

```ts
import '@automattic/charts/style.css'; // eslint-disable-line import/no-unresolved -- CSS subpath; dist/index.css is gitignored
```

**Both forms are observed to disappear during pre-commit `lint-file
--fix`** when new imports land in a file at the same time. The host
dogfood for [RSM-3713](https://linear.app/a8c/issue/RSM-3713) (PR #49)
saw the inline form stripped on the initial commit
(`dd52a32094`); a follow-up commit (`e60c87ea93`) re-added it, and
because that commit only changed the directive (not surrounding
imports), the strip didn't re-fire. Searching the full history:

```bash
git log --all -S 'eslint-disable-line import/no-unresolved' \
  -- projects/packages/premium-analytics/routes/dashboard/stage.tsx
```

…returns only `e60c87ea93` — meaning the prior "inline form already
ships in pie chart" assumption was unverified; no commit on
`fork/add/premium-analytics-pie-chart` actually contained the
directive either.

The pre-commit pipeline runs Prettier and `eslint --fix` via
`lint-file`. The `import/order` rule is configured with
`newlines-between: 'never'` + alphabetic ordering
(`tools/js-tools/eslintrc/base.mjs:318-325`). What exact step strips
the comment is still not isolated — see
[`docs/research/eslint-disable-line-discovery.md`](docs/research/eslint-disable-line-discovery.md)
for which mechanisms were ruled out across 5 rounds. The directive
itself is correct (lint and CI both pass when it's present); the
unreliable part is the formatter pipeline preserving it through a
new-imports commit.

**Operational rule:** after `git commit` lands a file with this
import, immediately run `git show HEAD -- <file>` and check the
directive is still on the import line. If it's gone, re-add it in a
follow-up commit; that commit's pre-commit pass typically lets the
comment through because nothing else is being rewritten.

### `@wordpress/boot` shim

`shims/boot-asset.php` is a compatibility shim copied into
`build/modules/boot/index.min.asset.php` during build. **Do not remove
or modify the shim copy step** — without it the boot chain fails to
register the admin page.

---

## Linear issue contract for `/premium-analytics-implement-task`

This package's `tasks/` directory is gone. Tasks live in Linear issues.

**Today (Phase 1):** the implement-task skill takes a path to a local
scratch md file (see the skill's "Input" section for the exact call
signature). A human translates the Linear issue description into that
scratch file before invoking the skill.

**Future (Phase 2, RSM-3707, not yet landed):** the skill will read the
Linear issue body directly via MCP; no scratch file needed.

The contract below applies to the issue description in both phases —
in Phase 1 it doubles as the scratch file's contents; in Phase 2 the
skill consumes it straight from Linear.

### Required

1. **What** — 1-3 sentences: current state → end state.
2. **Scope** — bulleted list of files the implementation may touch
   (paths relative to repo root). The skill enforces this as the single
   source of truth for what the task may modify.
3. **Implementation** — what to add or change, with the exact code /
   values where they matter. Reasoning for non-obvious choices should
   link back to the relevant section in this AGENTS.md, not be inlined.
4. **Definition of done** — two sub-lists:
   - *Agent-verifiable* — build, `/premium-analytics-verify-ui`, any
     regression-injection acceptance items.
   - *Human-verifiable* — visual / functional checks for PR review.
5. **Submitting** — branch name to create (e.g. `add/<topic>`) and the
   exact `pnpm jetpack changelogger add` command + entry.

### Recommended

- A short "Background" or "Why" paragraph if the task isn't
  self-explanatory.
- Links to related Linear issues / RFCs / Slack threads.

### What NOT to include

- **Implementation rationale.** Reasoning about *why* a particular
  library / API / pattern is being used is an invariant; it belongs in
  the "Common patterns and pitfalls" section above (so all task issues
  benefit, not just this one). If the rationale doesn't exist there
  yet, capture it during implementation via Step 10 of the
  implement-task skill.
- **Boilerplate constraints** that apply to every task in this package
  (no real endpoints in Phase 1, no `build/` edits, etc.). They live in
  the "Allowed without approval" / "Never do" sections above.
- **Session Report** template content. The skill fills that in
  automatically when it opens the PR.
