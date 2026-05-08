# Task: Dashboard — Line Chart (Mock Data)

## What

Add a line chart to the dashboard route to display page views over time, using mock data.
This is a UI-only change — no data fetching, no endpoints, no stores.

## Scope

You may only touch:

- `routes/dashboard/stage.tsx`
- `routes/dashboard/package.json` (only if a dependency needs to be added)
- `package.json` at the package root (only if a dependency needs to be added)

Do not create new routes, new packages, or new files outside this directory.

## Implementation

Import from `@automattic/charts`. Also import the chart CSS to avoid a ResizeObserver
height loop caused by inline SVG descender space:

```ts
import { LineChartUnresponsive } from '@automattic/charts';
import '@automattic/charts/style.css';
import type { SeriesData } from '@automattic/charts';
```

### Mock data

```ts
const PAGE_VIEWS: SeriesData[] = [
  {
    group: 'views',
    label: 'Page Views',
    data: [
      { label: 'Mon', value: 1200 },
      { label: 'Tue', value: 1900 },
      { label: 'Wed', value: 1500 },
      { label: 'Thu', value: 2200 },
      { label: 'Fri', value: 1800 },
      { label: 'Sat', value: 900 },
      { label: 'Sun', value: 700 },
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
The `svg { display: block }` rule in `@automattic/charts/style.css` prevents inline SVG
descender space from causing that internal measurement to drift upward on each cycle.

`@automattic/charts/style.css` must be explicitly imported — the package does not
auto-inject styles. Without it the rule is never applied and the chart height grows
indefinitely.

## Constraints

- Mock data only — do not fetch, do not invent endpoints or stores
- Do not claim these are real analytics metrics in any UI copy
- Do not modify anything outside `routes/dashboard/`
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
