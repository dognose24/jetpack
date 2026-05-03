<?php
/**
 * Must-use plugin: bootstraps premium-analytics standalone in the wp-verify environment.
 *
 * The package has no runtime composer dependencies (only php >= 7.2), so we load
 * the source classes directly via classmap instead of requiring a composer autoloader.
 *
 * @package automattic/jetpack-premium-analytics
 */

$src_dir   = WP_CONTENT_DIR . '/plugins/premium-analytics/src/';
$src_files = glob( $src_dir . '*.php' );
foreach ( $src_files ? $src_files : array() as $file ) {
	require_once $file;
}

add_action(
	'plugins_loaded',
	function () {
		if ( class_exists( 'Automattic\\Jetpack\\PremiumAnalytics\\Analytics' ) ) {
			\Automattic\Jetpack\PremiumAnalytics\Analytics::init();
		}
	},
	1
);
