# Task: Dashboard — Line Chart (Mock Data)

## What

Add a line chart to the dashboard route to display page views over time, using mock data.
This is a UI-only change — no data fetching, no endpoints, no stores.

## Scope

You may only touch:

- `routes/dashboard/stage.tsx`
- `routes/dashboard/package.json` (only if a dependency needs to be added)
- `projects/packages/premium-analytics/package.json` (only if a dependency needs to be added)
- `changelog/` (one entry added via `pnpm jetpack changelogger add`)

Do not create new routes, new packages, or new files outside these locations.

## Implementation

Import from `@automattic/charts`. Also import the chart CSS to avoid a ResizeObserver
height loop caused by inline SVG descender space:

```ts
import { LineChartUnresponsive } from '@automattic/charts';
import '@automattic/charts/style.css';
import type { SeriesData } from '@automattic/charts';
```

### Mock data

`LineChartUnresponsive` uses `DataPointDate` items — each point must have a `date` field
to be positioned on the x-axis. Using `DataPoint` (`{ label, value }` only) will render
the axes but not the data line.

```ts
const PAGE_VIEWS: SeriesData[] = [
  {
    label: 'Page Views',
    data: [
      { date: new Date( '2024-01-01' ), value: 1200, label: 'Mon' },
      { date: new Date( '2024-01-02' ), value: 1900, label: 'Tue' },
      { date: new Date( '2024-01-03' ), value: 1500, label: 'Wed' },
      { date: new Date( '2024-01-04' ), value: 2200, label: 'Thu' },
      { date: new Date( '2024-01-05' ), value: 1800, label: 'Fri' },
      { date: new Date( '2024-01-06' ), value: 900, label: 'Sat' },
      { date: new Date( '2024-01-07' ), value: 700, label: 'Sun' },
    ],
  },
];
```

### Rendering

Add a section heading and chart below the existing `<h1>`:

```tsx
<h2>{ __( 'Page Views', 'jetpack-premium-analytics' ) }</h2>
<LineChartUnresponsive data={ PAGE_VIEWS } width={ 600 } height={ 280 } />
```

## Why LineChartUnresponsive

`LineChartUnresponsive` skips the `withResponsive` HOC, which means it does not use
`useParentSize` to measure the parent container. This avoids one class of resize loop
where the chart measures its parent and the parent has no fixed height.

## Why the CSS import is still required

Even without the responsive wrapper, `ChartLayout` (used internally by all chart variants)
has a `ResizeObserver` that measures the content area height and feeds it back to the chart.
`@automattic/charts/style.css` includes a `.chart-layout__content svg { display: block }`
rule scoped to ChartLayout's content wrapper, which prevents inline SVG descender space
from causing that internal measurement to drift upward on each cycle.

`@automattic/charts/style.css` must be explicitly imported — the package does not
auto-inject styles. Without it the rule is never applied and the chart height grows
indefinitely.

## Constraints

- Mock data only — do not fetch, do not invent endpoints or stores
- Do not claim these are real analytics metrics in any UI copy
- Do not modify anything outside `routes/dashboard/`, `projects/packages/premium-analytics/package.json`, and the changelog entry — these are the only exceptions listed in Scope above
- Do not edit files in `build/`

## Definition of done

**Agent-verifiable (required before push):**
- [ ] Build succeeds
- [ ] UI verification passes: run `/premium-analytics-verify-ui` inside `jetpack-ai-sandbox`

**Human-verifiable (PR review):**
- [ ] Line chart renders in `wp-admin` with a stable height (no infinite growth)
- [ ] No uncaught JS exceptions in the browser console

## Submitting

1. Fetch the fork's trunk and create a new branch from it:
   ```bash
   git fetch fork
   git checkout -b add/premium-analytics-line-chart fork/trunk
   ```
2. Implement the changes.
3. Add a changelog entry:
   ```bash
   pnpm jetpack changelogger add packages/premium-analytics --significance=patch --type=added --entry="Analytics: Add page views line chart with mock data to dashboard."
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
