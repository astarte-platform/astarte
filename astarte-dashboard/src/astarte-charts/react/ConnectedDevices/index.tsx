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
import { Chart } from 'react-chartjs-2';
import { ChartProvider, ConnectedDevices } from 'astarte-charts';

import { useChartProviders } from '../hooks';

interface Props {
  provider: ChartProvider<'Object', ConnectedDevices>;
  height?: number;
  width?: number;
  showLegend?: boolean;
  legendPosition?: 'top' | 'left' | 'bottom' | 'right';
  legendAlign?: 'start' | 'center' | 'end';
  refreshInterval?: number;
}

export const ConnectedDevicesChart = ({
  provider,
  height,
  width,
  showLegend = true,
  legendPosition = 'right',
  legendAlign = 'start',
  refreshInterval,
}: Props): React.ReactElement => {
  const providers = useMemo(() => [provider], [provider]);

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
    const {
      data: { connected, disconnected },
    } = providerData;
    return {
      labels: ['Disconnected', 'Connected'],
      datasets: [
        {
          data: [disconnected.value, connected.value],
          backgroundColor: ['#cc5b6d', '#5bcc6c'],
        },
      ],
    };
  }, [dataFetcher.data]);

  const chartOptions = useMemo(
    () => ({
      responsive: true,
      legend: {
        display: showLegend,
        position: legendPosition,
        align: legendAlign,
      },
    }),
    [showLegend, legendPosition, legendAlign],
  );

  return <Chart type="pie" data={chartData} width={width} height={height} options={chartOptions} />;
};
