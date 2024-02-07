/*
   This file is part of Astarte.

   Copyright 2021-2024 SECO Mind Srl

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

import React, { useMemo } from 'react';
import 'chart.js/auto';
import { Chart, ChartProps } from 'react-chartjs-2';
import Color from 'color';

import { ChartProvider, TimestampedAggregated, TimestampedIndividual } from 'astarte-charts';

import { useChartProviders } from '../hooks';

type AggregatedProvider = ChartProvider<'Array', TimestampedAggregated>;
type IndividualProvider = ChartProvider<'Array', TimestampedIndividual>;

interface Props {
  providers: Array<AggregatedProvider | IndividualProvider>;
  height?: number;
  width?: number;
  showLegend?: boolean;
  scaleDistribution?: 'linear' | 'series';
  refreshInterval?: number;
}

export const TimeseriesChart = ({
  providers,
  height,
  width,
  showLegend = true,
  scaleDistribution = 'linear',
  refreshInterval,
}: Props): React.ReactElement => {
  const individualTimeseriesProviders = useMemo(
    () =>
      providers.filter(
        (provider) => provider.dataKind === TimestampedIndividual,
      ) as IndividualProvider[],
    [providers],
  );
  const aggregatedTimeseriesProviders = useMemo(
    () =>
      providers.filter(
        (provider) => provider.dataKind === TimestampedAggregated,
      ) as AggregatedProvider[],
    [providers],
  );

  const individualTimeseriesFetcher = useChartProviders({
    providers: individualTimeseriesProviders,
    refreshInterval,
  });
  const aggregatedTimeseriesFetcher = useChartProviders({
    providers: aggregatedTimeseriesProviders,
    refreshInterval,
  });

  const chartData = useMemo(() => {
    if (individualTimeseriesFetcher.data == null || aggregatedTimeseriesFetcher.data == null) {
      return { datasets: [] };
    }
    const colors = providers.map((provider, index) =>
      Color.hsl((index * 360) / providers.length, 70, 70)
        .rgb()
        .string(),
    );
    const individualProvidersTimeseries = individualTimeseriesFetcher.data.map(
      (providerData, providerIndex) => ({
        label: individualTimeseriesProviders[providerIndex].name,
        data: (providerData || []).map(({ timestamp, data: { value } }) => ({
          x: new Date(timestamp),
          y: Number(value),
        })),
        backgroundColor: colors[providerIndex],
        borderColor: colors[providerIndex],
        fill: false,
        borderWidth: 1,
        pointRadius: (providerData || []).length > 100 ? 0 : 3,
      }),
    );
    const aggregatedProvidersTimeseries = aggregatedTimeseriesFetcher.data
      .map((providerData, providerIndex) => {
        if (providerData == null || providerData.length === 0) {
          return [];
        }
        const providerEndpoints = Object.keys(providerData[0].data);
        return providerEndpoints.map((endpoint) => ({
          label: `${aggregatedTimeseriesProviders[providerIndex].name}/${endpoint}`,
          data: providerData.map((dataPoint) => ({
            x: new Date(dataPoint.timestamp),
            y: Number(dataPoint.data[endpoint].value),
          })),
          backgroundColor: colors[individualTimeseriesProviders.length + providerIndex],
          borderColor: colors[individualTimeseriesProviders.length + providerIndex],
          fill: false,
          borderWidth: 1,
          pointRadius: providerData.length > 100 ? 0 : 3,
        }));
      })
      .flat();
    return { datasets: individualProvidersTimeseries.concat(aggregatedProvidersTimeseries) };
  }, [individualTimeseriesFetcher.data, aggregatedTimeseriesFetcher.data]);

  const chartOptions: ChartProps<'line'>['options'] = useMemo(
    () => ({
      responsive: true,
      legend: {
        display: showLegend,
      },
      scales: {
        xAxes: {
          type: 'time',
          distribution: scaleDistribution,
          bounds: 'data',
        },
      },
      elements: {
        line: {
          tension: 0,
        },
      },
    }),
    [showLegend, scaleDistribution],
  );

  return (
    <Chart type="line" data={chartData} options={chartOptions} width={width} height={height} />
  );
};
