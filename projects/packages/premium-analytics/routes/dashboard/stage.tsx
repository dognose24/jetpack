import { LineChartUnresponsive } from '@automattic/charts';
import '@automattic/charts/style.css';
import { __ } from '@wordpress/i18n';
import type { SeriesData } from '@automattic/charts';

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

export const stage = () => {
	return (
		<div className="jetpack-premium-analytics-dashboard">
			<h1>{ __( 'Analytics', 'jetpack-premium-analytics' ) }</h1>
			<p>{ __( 'Welcome to the Analytics dashboard.', 'jetpack-premium-analytics' ) }</p>
			<h2>{ __( 'Page Views', 'jetpack-premium-analytics' ) }</h2>
			<LineChartUnresponsive data={ PAGE_VIEWS } width={ 600 } height={ 280 } />
		</div>
	);
};
