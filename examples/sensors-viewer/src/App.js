import './assets/css/cast.css'
import "bootstrap/dist/css/bootstrap.min.css";
import "jquery"
import "react-popper"

import React, {Component} from 'react';
import SensorViewer from "./components/SensorViewer";

class App extends Component {
    render() {
        return (
            <div>
                <SensorViewer/>
            </div>
        );
    }
}

export default App;
