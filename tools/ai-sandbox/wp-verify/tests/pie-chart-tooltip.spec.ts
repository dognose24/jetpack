/**
 * Pie chart hover/tooltip interaction.
 *
 * Currently SKIPPED — the dashboard route on `fork/trunk` is the clean state (no
 * charts). Unskip when the `dashboard-pie-chart` task lands a `PieChartUnresponsive`
 * on the dashboard (see `projects/packages/premium-analytics/tasks/dashboard-pie-chart.md`).
 *
 * Notes on hovering `@automattic/charts`:
 *
 * `@visx/tooltip`'s `useTooltipInPortal` renders the tooltip outside the chart's DOM
 * subtree (typically appended to the chart's `containerRef` or `document.body`). Match it
 * by content, not by class.
 *
 * `locator.hover()` over SVG children sometimes fails to fire visx's mouse handlers
 * because the handlers are attached to the parent `<g>`. The robust pattern is
 * `page.mouse.move( box.x + box.width / 2, box.y + box.height / 2 )` after grabbing the
 * segment's bounding box.
 *
 * Tooltips fade in within one animation frame; rely on `expect(...).toBeVisible()` with a
 * small timeout rather than a fixed sleep.
 */

import { test, expect } from '@playwright/test';

const ANALYTICS_URL = '/wp-admin/admin.php?page=jetpack-premium-analytics';
const DASHBOARD_ROOT = '.jetpack-premium-analytics-dashboard';

test.describe.skip( 'Pie chart interactions', () => {
	test( 'hover on a segment reveals tooltip with the segment label and value', async ( {
		page,
	} ) => {
		await page.goto( ANALYTICS_URL );
		await page.waitForSelector( DASHBOARD_ROOT );

		const firstSegment = page.locator( `${ DASHBOARD_ROOT } svg path` ).first();
		await firstSegment.waitFor();

		const box = await firstSegment.boundingBox();
		if ( ! box ) {
			throw new Error( 'Could not get bounding box for the first pie segment' );
		}
		await page.mouse.move( box.x + box.width / 2, box.y + box.height / 2 );

		// Scope to the visx-tooltip portal container so we don't false-positive on legend
		// labels (which also render the device-type strings). Then assert the tooltip is
		// visible and contains one of the expected labels.
		const tooltip = page.locator( '.visx-tooltip' );
		await expect( tooltip ).toBeVisible( { timeout: 5_000 } );
		await expect( tooltip ).toContainText( /Desktop|Mobile|Tablet/ );
	} );
} );
