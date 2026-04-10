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
