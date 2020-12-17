/*
   This file is part of Astarte.

   Copyright 2020 Ispirata Srl

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

import React, { useEffect, useState } from 'react';
import Color from 'color';
import { Col } from 'react-bootstrap';
import { Pie } from 'react-chartjs-2';
import type { ChartData } from 'chart.js';

interface DeviceData {
  name: string;
  bytes: number;
}

interface DeviceDataPieChart {
  stats: DeviceData[];
}

interface LegendItem {
  name: string;
  color: string;
}

const chartOptions = {
  responsive: true,
  maintainAspectRatio: false,
  legend: {
    display: false,
  },
};

const DeviceDataPieChart = ({ stats }: DeviceDataPieChart): React.ReactElement => {
  const [pieData, setPieData] = useState<ChartData>({});
  const [chartLegend, setChartLegend] = useState<LegendItem[]>([]);

  useEffect(() => {
    const colors: string[] = [];
    const data: number[] = [];
    const labels: string[] = [];

    const legend: LegendItem[] = [];

    stats
      .filter(({ name }) => name !== 'Total')
      .forEach(({ name, bytes }, index) => {
        const color: string = Color.hsl(36 + (index * 360) / (stats.length - 1), 70, 70)
          .rgb()
          .string();

        labels.push(name);
        data.push(bytes);
        colors.push(color);
        legend.push({ name, color });
      });

    setPieData({
      labels,
      datasets: [
        {
          data,
          backgroundColor: colors,
          label: 'Device sent data',
        },
      ],
    });

    setChartLegend(legend);
  }, [stats]);

  return (
    <Col sm={12} xl={4} className="d-flex justify-content-center flex-wrap-reverse">
      <div className="chart-container">
        <Pie data={pieData} options={chartOptions} />
      </div>
      <ul className="list-unstyled d-inline-block ml-2" style={{ verticalAlign: 'top' }}>
        {chartLegend.map(({ name, color }) => (
          <li key={name}>
            <span className="square mr-1" style={{ backgroundColor: color }} />
            {name}
          </li>
        ))}
      </ul>
    </Col>
  );
};

export default DeviceDataPieChart;
