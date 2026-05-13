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
`eslint-disable-next-line` comment is required — see "Why the CSS import" below.

```ts
// Insert these two statements above the existing @wordpress/i18n import:
import {
	PieChartUnresponsive,
	type DataPointPercentage,
} from '@automattic/charts';
// eslint-disable-next-line import/no-unresolved -- CSS subpath export; dist/index.css is gitignored and not built in the ESLint CI step
import '@automattic/charts/style.css';
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
existing `.jetpack-premium-analytics-dashboard` wrapper:

```tsx
<h2>{ __( 'Device Types', 'jetpack-premium-analytics' ) }</h2>
<PieChartUnresponsive data={ DEVICE_TYPES } width={ 360 } height={ 360 } />
```

The final `stage.tsx` body should read:

```tsx
<div className="jetpack-premium-analytics-dashboard">
	<h1>{ __( 'Analytics', 'jetpack-premium-analytics' ) }</h1>
	<p>{ __( 'Welcome to the Analytics dashboard.', 'jetpack-premium-analytics' ) }</p>
	<h2>{ __( 'Device Types', 'jetpack-premium-analytics' ) }</h2>
	<PieChartUnresponsive data={ DEVICE_TYPES } width={ 360 } height={ 360 } />
</div>
```

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

The `eslint-disable-next-line import/no-unresolved` comment is required because
`@automattic/charts/style.css` is a subpath export that resolves to `dist/index.css`,
which is gitignored and the ESLint CI step does not run the charts package build, so the
resolver cannot find the file at lint time. Leave the comment in place; do not edit its
text or remove it.

## Constraints

- Mock data only — do not fetch, do not invent endpoints or stores
- Do not claim these are real device-breakdown metrics in any UI copy
- Do not modify anything outside `routes/dashboard/`, `routes/dashboard/package.json`, `projects/packages/premium-analytics/package.json`, and the changelog entry — these are the only exceptions listed in Scope above
- Do not edit files in `build/`
- Do not change the existing `<h1>` or welcome paragraph

## Definition of done

**Agent-verifiable (required before push):**
- [ ] Build succeeds
- [ ] UI verification passes: run `/premium-analytics-verify-ui` inside `jetpack-ai-sandbox`

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
