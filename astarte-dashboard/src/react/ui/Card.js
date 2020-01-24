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

import React from "react";

export default class Card extends React.Component {
  constructor(props) {
    super(props);
  }

  render() {
    return (
      <div id="groups-card" className="container-fluid bg-white rounded pb-3">
        <div className="row mt-2">
          <div className="col-sm-12"></div>
        </div>
        <div className="row mt-2">
          <div className="col-sm-12">
            <h2 className="d-inline text-secondary font-weight-normal align-middle">
              {this.props.title}
            </h2>
          </div>
        </div>
        <div className="row mt-4">
          <div className="col-sm-12">{this.props.children}</div>
        </div>
      </div>
    );
  }
}
