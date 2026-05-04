<?php
/**
 * Must-use plugin: bootstraps premium-analytics standalone in the wp-verify environment.
 *
 * The package has no runtime composer dependencies (only php >= 7.2), so we load
 * the entry file directly via require_once (no classmap or composer autoloader needed).
 *
 * @package automattic/jetpack-premium-analytics
 */

$entry = WP_CONTENT_DIR . '/plugins/premium-analytics/src/class-analytics.php';
if ( ! file_exists( $entry ) ) {
	wp_die( 'premium-analytics entry point not found: ' . esc_html( $entry ) );
}
require_once $entry;

add_action(
	'plugins_loaded',
	function () {
		if ( class_exists( 'Automattic\\Jetpack\\PremiumAnalytics\\Analytics' ) ) {
			\Automattic\Jetpack\PremiumAnalytics\Analytics::init();
		}
	},
	1
);
