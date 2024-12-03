// Copyright 2020 SECO Mind Srl
//
// SPDX-License-Identifier: Apache-2.0

import "bootstrap/dist/css/bootstrap.min.css";
import "./assets/css/cast.css";

import ReactDOM from "react-dom";
import SensorViewer from "./components/SensorViewer";
import React from "react";

ReactDOM.render(
  <div>
    <SensorViewer />
  </div>,
  document.getElementById("root")
);
