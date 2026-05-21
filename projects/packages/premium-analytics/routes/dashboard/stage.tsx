import { BarChartUnresponsive, type SeriesData } from '@automattic/charts';
import '@automattic/charts/style.css';
import { __ } from '@wordpress/i18n';

const TOP_PAGES: SeriesData[] = [
	{
		label: __( 'Pageviews', 'jetpack-premium-analytics' ),
		data: [
			{ label: '/blog/welcome', value: 4200 },
			{ label: '/about', value: 2900 },
			{ label: '/pricing', value: 2150 },
			{ label: '/blog/launch', value: 1700 },
			{ label: '/contact', value: 980 },
		],
	},
];

export const stage = () => {
	return (
		<div className="jetpack-premium-analytics-dashboard">
			<h1>{ __( 'Analytics', 'jetpack-premium-analytics' ) }</h1>
			<p>{ __( 'Welcome to the Analytics dashboard.', 'jetpack-premium-analytics' ) }</p>
			<h2>{ __( 'Top Pages', 'jetpack-premium-analytics' ) }</h2>
			<BarChartUnresponsive data={ TOP_PAGES } width={ 600 } height={ 280 } />
		</div>
	);
};
