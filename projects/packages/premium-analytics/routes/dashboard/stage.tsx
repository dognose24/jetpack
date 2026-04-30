import { PieChart, LineChartUnresponsive, BarListChartUnresponsive } from '@automattic/charts';
import { __ } from '@wordpress/i18n';
import type { DataPointPercentage, SeriesData } from '@automattic/charts';

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

export const stage = () => {
	return (
		<div className="jetpack-premium-analytics-dashboard">
			<h1>{ __( 'Analytics', 'jetpack-premium-analytics' ) }</h1>
			<p>{ __( 'Welcome to the Analytics dashboard.', 'jetpack-premium-analytics' ) }</p>

			<h2>{ __( 'Traffic Sources', 'jetpack-premium-analytics' ) }</h2>
			<PieChart data={ TRAFFIC_SOURCES } size={ 300 } withTooltips />

			<h2>{ __( 'Page Views', 'jetpack-premium-analytics' ) }</h2>
			<LineChartUnresponsive data={ PAGE_VIEWS } width={ 600 } height={ 280 } />

			<h2>{ __( 'Top Pages', 'jetpack-premium-analytics' ) }</h2>
			<BarListChartUnresponsive data={ TOP_PAGES } width={ 600 } height={ 280 } />
		</div>
	);
};
