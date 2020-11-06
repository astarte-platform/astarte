/*
   This file is part of Astarte.

   Copyright 2021 Ispirata Srl

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
import { Pie } from 'react-chartjs-2';
import Color from 'color';
import { ChartProvider, Aggregated } from 'astarte-charts';

import { useChartProviders } from '../hooks';

interface Props<Kind extends Aggregated = Aggregated> {
  providers: [ChartProvider<'Object', Kind>];
  height?: number;
  width?: number;
  showLegend?: boolean;
  legendPosition?: 'top' | 'left' | 'bottom' | 'right';
  legendAlign?: 'start' | 'center' | 'end';
  refreshInterval?: number;
}

export const PieChart = <Kind extends Aggregated = Aggregated>({
  providers,
  height,
  width,
  showLegend = true,
  legendPosition = 'top',
  legendAlign = 'start',
  refreshInterval,
}: Props<Kind>): React.ReactElement => {
  const dataFetcher = useChartProviders({ providers, refreshInterval });

  const chartData = useMemo(() => {
    const noChartData = { labels: [], datasets: [] };
    if (dataFetcher.data == null) {
      return noChartData;
    }
    const providerData = dataFetcher.data[0];
    if (providerData == null) {
      return noChartData;
    }
    const { data } = providerData;
    const labels = Object.keys(data);
    const series = labels.map((label) => Number(data[label].value));
    const colors = labels.map((label, index) =>
      Color.hsl((index * 360) / labels.length, 70, 70)
        .rgb()
        .string(),
    );
    return {
      labels,
      datasets: [
        {
          data: series,
          backgroundColor: colors,
        },
      ],
    };
  }, [dataFetcher.data]);

  const chartOptions = useMemo(
    () => ({
      responsive: true,
      maintainAspectRatio: false,
      legend: {
        display: showLegend,
        position: legendPosition,
        align: legendAlign,
      },
    }),
    [showLegend, legendPosition, legendAlign],
  );

  return <Pie data={chartData} width={width} height={height} options={chartOptions} />;
};
