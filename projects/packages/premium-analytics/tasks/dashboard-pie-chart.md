# Task: Dashboard — Pie Chart (Mock Data)

## What

Add a pie chart to the dashboard route to display the breakdown of visitors by device
type, using mock data. This is a UI-only change — no data fetching, no endpoints, no
stores.

The starting point is the clean `fork/trunk` dashboard: an `<h1>Analytics</h1>` heading
and a welcome paragraph, no charts. After this task the dashboard will also contain a
device-types pie chart rendered with `PieChartUnresponsive` from `@automattic/charts`.

## Scope

You may only touch:

- `routes/dashboard/stage.tsx`
- `routes/dashboard/package.json` — add `@automattic/charts` as a dependency
- `projects/packages/premium-analytics/package.json` (only if a dependency needs to be added)
- `tools/ai-sandbox/wp-verify/tests/pie-chart-tooltip.spec.ts` — unskip the placeholder spec and prune its header note
- `changelog/` (one entry added via `pnpm jetpack changelogger add`)

Do not create new routes, new packages, or new files outside these locations.

## Implementation

### Add the dependency

`@automattic/charts` must be declared in **two** package.json files. The pnpm workspace
globs (`projects/*/*`) only register top-level package directories, so the
`projects/packages/premium-analytics` entry is what makes the workspace resolution
succeed. The route-local entry exists for bundler/dependency-graph metadata. Both are
needed — omitting either has produced module-resolution or build failures in prior
runs.

Add `@automattic/charts` to the existing `dependencies` block in each file (do not
remove any other fields):

1. `projects/packages/premium-analytics/package.json` — add only this line under
   `dependencies` (keep `@wordpress/boot`, `@wordpress/data`, `@wordpress/i18n`,
   `@wordpress/icons`, `@wordpress/route`, `react`, `react-dom`, etc. unchanged):
   ```jsonc
   "@automattic/charts": "workspace:*",
   ```

2. `routes/dashboard/package.json` — add only this line under `dependencies` (keep
   `private`, `name`, `route`, and the existing `@wordpress/i18n` entry unchanged):
   ```jsonc
   "@automattic/charts": "workspace:*",
   ```

### Imports

Add the two new import statements shown below. Leave the existing
`import { __ } from '@wordpress/i18n';` line unchanged — do not re-add it. The
inline `eslint-disable-line` comment on the CSS import line is required — see
"Why the CSS import is required" below for the rationale, and "Why the disable
comment must be inline" for why it lives at the end of the line and not on the
line above.

```ts
// Insert these two statements above the existing @wordpress/i18n import:
import {
	PieChartUnresponsive,
	type DataPointPercentage,
} from '@automattic/charts';
import '@automattic/charts/style.css'; // eslint-disable-line import/no-unresolved -- CSS subpath export; dist/index.css is gitignored and not built in the ESLint CI step
```

### Mock data

`PieChartUnresponsive` uses `DataPointPercentage` items — each needs only `label` and
`value`. Percentages are calculated automatically from the values.

Add the constant above the `stage` export:

```ts
const DEVICE_TYPES: DataPointPercentage[] = [
	{ label: 'Desktop', value: 5400 },
	{ label: 'Mobile', value: 3800 },
	{ label: 'Tablet', value: 800 },
];
```

Order matters visually: list segments largest-to-smallest so the pie renders in a
predictable rotation.

### Rendering

Add a section heading and the chart **below** the existing welcome paragraph, inside the
existing `.jetpack-premium-analytics-dashboard` wrapper. The `withTooltips` prop is
required so the hover acceptance check in the Definition of Done can validate the visx
tooltip portal — without it `PieChartUnresponsive` skips its mouse handlers and the
`pie-chart-tooltip.spec.ts` assertion fails before it can be exercised:

```tsx
<h2>{ __( 'Device Types', 'jetpack-premium-analytics' ) }</h2>
<PieChartUnresponsive data={ DEVICE_TYPES } width={ 360 } height={ 360 } withTooltips />
```

The final `stage.tsx` body should read:

```tsx
<div className="jetpack-premium-analytics-dashboard">
	<h1>{ __( 'Analytics', 'jetpack-premium-analytics' ) }</h1>
	<p>{ __( 'Welcome to the Analytics dashboard.', 'jetpack-premium-analytics' ) }</p>
	<h2>{ __( 'Device Types', 'jetpack-premium-analytics' ) }</h2>
	<PieChartUnresponsive data={ DEVICE_TYPES } width={ 360 } height={ 360 } withTooltips />
</div>
```

### Unskip the hover/tooltip interaction spec

`tools/ai-sandbox/wp-verify/tests/pie-chart-tooltip.spec.ts` ships as a `test.describe.skip(...)` placeholder. With the pie chart now on the dashboard, the spec can run.

1. Change `test.describe.skip( 'Pie chart interactions', () => {` → `test.describe( 'Pie chart interactions', () => {`.
2. Drop the leading "Currently SKIPPED — …" paragraph from the file's header comment. Keep the visx-portal note and SVG-hover note — both remain relevant for anyone touching the spec later.

After unskipping, the full suite output should be `4 passed (0 skipped)`: the three dashboard-mount tests (the zero-height-SVG test no longer skips because an SVG is now present) plus the unskipped pie-chart hover test.

## Why PieChartUnresponsive

`PieChartUnresponsive` skips the `withResponsive` HOC, which means it does not use
`useParentSize` to measure the parent container. This avoids one class of resize loop
where the chart measures its parent and the parent has no fixed height.

## Why the CSS import is required

Even without the responsive wrapper, `ChartLayout` (used internally by all chart variants)
has a `ResizeObserver` that measures the content area height and feeds it back to the
chart. `@automattic/charts/style.css` includes a `.chart-layout__content svg { display:
block }` rule scoped to ChartLayout's content wrapper, which prevents inline SVG
descender space from causing that internal measurement to drift upward on each cycle.

`@automattic/charts/style.css` must be explicitly imported — the package does not
auto-inject styles. Without it the rule is never applied and the chart height grows
indefinitely.

The inline `eslint-disable-line import/no-unresolved` comment is required because
`@automattic/charts/style.css` is a subpath export that resolves to `dist/index.css`,
which is gitignored and the ESLint CI step does not run the charts package build, so the
resolver cannot find the file at lint time. Leave the comment in place; do not edit its
text or remove it.

## Why the disable comment must be inline

Use `eslint-disable-line` on the same line as the import — **not** `eslint-disable-next-line` on the line above. The next-line form looks cleaner but doesn't survive this repo's lint/format toolchain end-to-end:

* The pre-commit pipeline reorders imports via ESLint `import/order` (`'newlines-between': 'never'`, alphabetic). A standalone `eslint-disable-next-line` comment placed between imports can end up detached from the import it was meant to annotate after the pipeline runs.
* Once the comment is no longer immediately above the unresolved import, ESLint's `--fix` sees the comment as "unused" — locally the `@automattic/charts/dist/index.css` file exists (charts package is built), so the `import/no-unresolved` rule doesn't fire there, and the disable comment gets removed.
* On CI the lint job runs without the charts package built. The import is unresolved, but the disable comment was already deleted locally in the previous step and committed away — so CI lint fails.

The inline `eslint-disable-line` form has none of these failure modes: trailing comments don't move during import reordering, and ESLint won't auto-remove a comment whose target rule actually fires (in CI where the file is genuinely unresolved).

## Constraints

- Mock data only — do not fetch, do not invent endpoints or stores
- Do not claim these are real device-breakdown metrics in any UI copy
- Do not modify anything outside the files listed in the Scope section above — that list is the single source of truth for what this task may touch
- Do not edit files in `build/`
- Do not change the existing `<h1>` or welcome paragraph

## Definition of done

**Agent-verifiable (required before push):**
- [ ] Build succeeds
- [ ] UI verification passes: run `/premium-analytics-verify-ui` inside `jetpack-ai-sandbox` — output is `4 passed (0 skipped)`
- [ ] **Hover regression injection** (local-only, do not commit): change `'Desktop'` → `'Workstation'` in `DEVICE_TYPES`, rebuild, rerun the suite, confirm `pie-chart-tooltip.spec.ts` fails on the `toContainText(/Desktop|Mobile|Tablet/)` assertion, then revert and confirm the suite is green again. This proves the hover/tooltip mechanism actually catches a tooltip-content regression rather than passing vacuously.

**Human-verifiable (PR review):**
- [ ] Pie chart renders in `wp-admin` below the welcome paragraph with three labelled segments (Desktop, Mobile, Tablet)
- [ ] Chart height is stable — no infinite growth
- [ ] No uncaught JS exceptions in the browser console

## Submitting

1. Fetch the fork's trunk and create a new branch from it:
   ```bash
   git fetch fork
   git checkout -b add/premium-analytics-pie-chart fork/trunk
   ```
2. Implement the changes.
3. Add a changelog entry:
   ```bash
   pnpm jetpack changelogger add packages/premium-analytics --significance=patch --type=added --entry="Analytics: Add device types pie chart with mock data to dashboard."
   ```
4. Commit all changes including the changelog entry.
5. Push the branch to the fork and open a PR against `dognose24/jetpack` trunk.

## Session Report

Fill this out in the PR description:

```
## Agent Session Report
- Scope respected: yes / no
- Escalations triggered: N
- Contract violations: none / [describe]
- Human rework needed: none / minor / major
```
