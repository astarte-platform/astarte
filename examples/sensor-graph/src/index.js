// Copyright 2020 SECO Mind Srl
//
// SPDX-License-Identifier: Apache-2.0

import React from "react";
import ReactDOM from "react-dom";
import SensorPlotGraph from "./components/SensorPlotGraph";

import "bootstrap/dist/css/bootstrap.min.css";
import "./assets/css/cast.css";

ReactDOM.render(
  <div>
    <SensorPlotGraph />
  </div>,
  document.getElementById("root")
);
