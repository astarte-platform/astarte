// Copyright 2020 SECO Mind Srl
//
// SPDX-License-Identifier: Apache-2.0

import React from "react";
import ReactDOM from "react-dom";

import "bootstrap/dist/css/bootstrap.min.css";
import "./assets/css/cast.css";
import SensorDisplay from "./components/SensorDisplay";
ReactDOM.render(
  <div>
    <SensorDisplay />
  </div>,
  document.getElementById("root")
);
