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
