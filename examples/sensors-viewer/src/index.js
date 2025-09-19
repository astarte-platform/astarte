import "bootstrap/dist/css/bootstrap.min.css";
import "jquery";
import "react-popper";
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
