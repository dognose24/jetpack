# Task: Dashboard — More Charts (Mock Data)

## What

Add three charts to the dashboard route using mock data: a pie chart (traffic sources),
a line chart (page views over time), and a bar list chart (top pages).
This is a UI-only change — no data fetching, no endpoints, no stores.

## Scope

You may only touch:

- `routes/dashboard/stage.tsx`
- `routes/dashboard/package.json` (only if a dependency needs to be added)
- `package.json` at the package root (only if a dependency needs to be added)

Do not create new routes, new packages, or new files outside this directory.

## Implementation

Import from `@automattic/charts`:

```ts
import { PieChart, LineChartUnresponsive, BarListChartUnresponsive } from '@automattic/charts';
import type { DataPointPercentage, SeriesData } from '@automattic/charts';
```

### Mock data

```ts
const TRAFFIC_SOURCES: DataPointPercentage[] = [
  { label: 'Direct', value: 4200 },
  { label: 'Search', value: 3100 },
  { label: 'Social', value: 1800 },
  { label: 'Referral', value: 900 },
];

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

const TOP_PAGES: SeriesData[] = [
  {
    group: 'primary',
    label: 'Top Pages',
    data: [
      { label: '/blog/getting-started', value: 3200 },
      { label: '/pricing', value: 2100 },
      { label: '/about', value: 1500 },
      { label: '/contact', value: 980 },
      { label: '/', value: 870 },
    ],
  },
];
```

### Rendering

Render all three charts inside `stage()` below the existing heading, in this order:

1. **Traffic Sources** — `PieChart` with `size={ 300 }` and `withTooltips`
2. **Page Views** — `LineChartUnresponsive` with `width={ 600 }` and `height={ 280 }`
3. **Top Pages** — `BarListChartUnresponsive` with `width={ 600 }` and `height={ 280 }`

Use a section heading (`<h2>`) above each chart with neutral copy that does not imply
real analytics data (e.g. "Traffic Sources", "Page Views", "Top Pages").

## Why fixed dimensions

`LineChartUnresponsive` and `BarListChartUnresponsive` accept explicit `width`/`height` props
and skip ResizeObserver. This avoids the feedback loop that occurs when a chart measures
its parent container and the parent has no fixed height.

## Constraints

- Mock data only — do not fetch, do not invent endpoints or stores
- Do not claim these are real analytics metrics in any UI copy
- Do not modify anything outside `routes/dashboard/`
- Do not edit files in `build/`

## Definition of done

**Agent-verifiable (required before push):**
- [ ] Build succeeds

**Human-verifiable (PR review):**
- [ ] All three charts render in `wp-admin` without blank screen or console errors
- [ ] Tooltips appear on hover for PieChart
- [ ] No infinite resize loop

## Submitting

1. Fetch the fork's trunk and create a new branch from it:
   ```bash
   git fetch fork
   git checkout -b add/premium-analytics-dashboard-more-charts fork/trunk
   ```
2. Implement the changes.
3. Add a changelog entry:
   ```bash
   pnpm jetpack changelogger add packages/premium-analytics --significance=patch --type=added --entry="Analytics: Add page views, traffic sources, and top pages charts with mock data to dashboard."
   ```
4. Commit all changes including the changelog entry.
5. Push the branch to the fork:
   ```bash
   git push fork add/premium-analytics-dashboard-more-charts
   ```
6. Open a **draft PR** against `dognose24/jetpack` trunk:
   ```bash
   gh pr create --repo dognose24/jetpack --base trunk --draft \
     --title "premium-analytics: Add more charts with mock data to dashboard" \
     --body "..."
   ```
7. PR description must include the Session Report below.
8. Immediately after the PR is created, run the review cycle:
   ```
   /jetpack-pr-review-cycle
   ```
   (PR number is auto-detected from the current branch.)

## Session Report

Fill this out in the PR description:

```
## Agent Session Report
- Scope respected: yes / no
- Escalations triggered: N
- Contract violations: none / [describe]
- Human rework needed: none / minor / major
```
