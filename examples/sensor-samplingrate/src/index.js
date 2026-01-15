import "bootstrap/dist/css/bootstrap.min.css";
import "./assets/css/cast.css";

import React from "react";
import ReactDOM from "react-dom";
import SensorViewer from "./components/SensorViewer";

ReactDOM.render(
  <div>
    <SensorViewer />
  </div>,
  document.getElementById("root"),
);
