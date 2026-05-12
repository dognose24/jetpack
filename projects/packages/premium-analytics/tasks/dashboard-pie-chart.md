# Task: Dashboard — Pie Chart (Mock Data)

## What

Add a pie chart to the dashboard route to display the breakdown of visitors by device
type, using mock data. This is a UI-only change — no data fetching, no endpoints, no
stores.

## Prerequisite

This task assumes `dashboard-line-chart` is already merged into `fork/trunk`. The line
chart's CSS import (`@automattic/charts/style.css`) and the existing chart `<h2>` /
`<LineChartUnresponsive>` block are reused as-is. Do not remove or rewrite them.

## Scope

You may only touch:

- `routes/dashboard/stage.tsx`
- `routes/dashboard/package.json` (only if a dependency needs to be added)
- `projects/packages/premium-analytics/package.json` (only if a dependency needs to be added)
- `changelog/` (one entry added via `pnpm jetpack changelogger add`)

Do not create new routes, new packages, or new files outside these locations.

## Implementation

Extend the existing imports from `@automattic/charts` to add `PieChartUnresponsive` and
the `DataPointPercentage` type. The exact shape of the existing imports depends on what
`dashboard-line-chart` merged with — at the time of writing, the line-chart task spec
shows separate value/type imports but the merged implementation combines them into one
statement. Match whichever shape is in the file when you start; if you find separate
value and type imports, combine them as you add the new symbols (this is in scope and
consistent with the merged line-chart state).

The `@automattic/charts/style.css` import path must remain unchanged. The
`eslint-disable-next-line import/no-unresolved` comment above it suppresses a false
positive: `@automattic/charts/style.css` is a subpath export that resolves to
`dist/index.css`, but `dist/` is gitignored and the ESLint CI step does not run the
charts package build, so the resolver cannot find the file at lint time. Leave the
comment in place; do not edit its text or remove it.

Final import block (combined-import shape):

```ts
import {
	LineChartUnresponsive,
	PieChartUnresponsive,
	type SeriesData,
	type DataPointPercentage,
} from '@automattic/charts';
// eslint-disable-next-line import/no-unresolved -- CSS subpath export; dist/index.css is gitignored and not built in the ESLint CI step
import '@automattic/charts/style.css'; // already present from line chart — keep, do not re-add
import { __ } from '@wordpress/i18n';
```

### Mock data

`PieChartUnresponsive` uses `DataPointPercentage` items — each needs only `label` and
`value`. Percentages are calculated automatically from the values.

Add the constant alongside `PAGE_VIEWS`:

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

Add a section heading and chart **below** the existing Page Views block — do not move,
wrap, or restyle the line chart:

```tsx
<h2>{ __( 'Device Types', 'jetpack-premium-analytics' ) }</h2>
<PieChartUnresponsive data={ DEVICE_TYPES } width={ 360 } height={ 360 } />
```

## Why PieChartUnresponsive

Same reason as the line chart: `PieChartUnresponsive` skips the `withResponsive` HOC,
which means it does not use `useParentSize` to measure the parent container. This avoids
one class of resize loop where the chart measures its parent and the parent has no fixed
height.

`ChartLayout`'s internal `ResizeObserver` still applies, so the chart CSS import
(`@automattic/charts/style.css`) is still required — but it is already in the file from
the line chart task, so no new import is needed here.

## Constraints

- Mock data only — do not fetch, do not invent endpoints or stores
- Do not claim these are real device-breakdown metrics in any UI copy
- Do not modify anything outside `routes/dashboard/`, `routes/dashboard/package.json`, `projects/packages/premium-analytics/package.json`, and the changelog entry — these are the only exceptions listed in Scope above
- Do not edit files in `build/`
- Do not change the line chart's mock data, dimensions, or heading

## Definition of done

**Agent-verifiable (required before push):**
- [ ] Build succeeds
- [ ] UI verification passes: run `/premium-analytics-verify-ui` inside `jetpack-ai-sandbox`

**Human-verifiable (PR review):**
- [ ] Pie chart renders in `wp-admin` below the line chart with three labelled segments
- [ ] Line chart still renders unchanged at its original dimensions
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
