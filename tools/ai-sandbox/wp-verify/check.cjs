// CommonJS so NODE_PATH is honoured when resolving the globally-installed playwright package.
// Wrapped in an async IIFE because top-level await is not valid in CommonJS.
/* eslint-disable no-console */
/* global process */

const fs = require( 'fs' );
const path = require( 'path' );
const { chromium } = require( 'playwright' );

( async () => {
	const WP_BASE = process.env.WP_BASE || 'http://wordpress';
	const ANALYTICS_URL = `${ WP_BASE }/wp-admin/admin.php?page=jetpack-premium-analytics`;
	const SCREENSHOT_DIR = process.env.SCREENSHOT_DIR || '/tmp/pa-verify';
	const SCREENSHOT_PATH = path.join( SCREENSHOT_DIR, 'analytics-dashboard.png' );

	fs.mkdirSync( SCREENSHOT_DIR, { recursive: true } );

	let browser;
	try {
		browser = await chromium.launch( { args: [ '--no-sandbox', '--disable-setuid-sandbox' ] } );
		const page = await browser.newPage();
		const pageErrors = [];

		// Only capture JS runtime exceptions — not HTTP-level console.error noise
		// (e.g. Gutenberg background API calls that 404 in the minimal test environment).
		page.on( 'pageerror', err => pageErrors.push( err.message ) );
		// Login
		await page.goto( `${ WP_BASE }/wp-login.php` );
		await page.fill( '#user_login', 'admin' );
		await page.fill( '#user_pass', 'password' );
		await page.click( '#wp-submit' );
		await page.waitForURL( '**/wp-admin/**' );

		// Navigate to Analytics
		await page.goto( ANALYTICS_URL );

		// Wait for React to mount
		await page
			.waitForSelector( '.jetpack-premium-analytics-dashboard', { timeout: 15000 } )
			.catch( () => {
				throw new Error( 'Dashboard root not found — React may not have mounted' );
			} );

		// Assert the dashboard heading rendered
		const heading = await page
			.$eval( '.jetpack-premium-analytics-dashboard h1', el => el.textContent.trim() )
			.catch( () => {
				throw new Error( 'Dashboard h1 not found — React may not have rendered' );
			} );
		if ( heading !== 'Analytics' ) {
			throw new Error( `Unexpected dashboard heading: "${ heading }"` );
		}

		await page.screenshot( { path: SCREENSHOT_PATH, fullPage: false } );

		if ( pageErrors.length ) {
			throw new Error( 'Uncaught JS exceptions detected:\n' + pageErrors.join( '\n' ) );
		}

		// Generic health: dashboard element must not grow beyond a reasonable height.
		// Scoped to the dashboard root to avoid false positives from wp-admin chrome
		// (notices, help panels, etc.). An abnormally tall dashboard (>10 000 px) indicates
		// an infinite resize loop inside the analytics UI.
		const dashboardHeight = await page.$eval(
			'.jetpack-premium-analytics-dashboard',
			el => el.scrollHeight
		);
		if ( dashboardHeight > 10000 ) {
			throw new Error(
				`Dashboard height ${ dashboardHeight }px exceeds limit — possible infinite resize loop`
			);
		}

		// Generic health: no SVG inside the dashboard should have zero height after render.
		// Poll for up to 2 s to allow responsive charts to settle after initial mount
		// before concluding that a zero-height SVG is a real failure.
		const POLL_INTERVAL = 200;
		const POLL_TIMEOUT = 2000;
		let collapsedSvgs = 0;
		const deadline = Date.now() + POLL_TIMEOUT;
		do {
			collapsedSvgs = await page.$$eval(
				'.jetpack-premium-analytics-dashboard svg',
				els => els.filter( el => el.getBoundingClientRect().height === 0 ).length
			);
			if ( collapsedSvgs === 0 ) break;
			await new Promise( resolve => setTimeout( resolve, POLL_INTERVAL ) );
		} while ( Date.now() < deadline );
		if ( collapsedSvgs > 0 ) {
			throw new Error(
				`${ collapsedSvgs } SVG(s) in dashboard have zero height — charts may not have rendered`
			);
		}

		console.log( '✓ Analytics dashboard mounted without uncaught JS exceptions' );
		console.log( `  dashboard height: ${ dashboardHeight }px` );
		console.log( `Screenshot saved to ${ SCREENSHOT_PATH }` );
	} finally {
		await browser?.close();
	}
} )();
