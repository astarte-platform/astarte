// Copyright 2021 SECO Mind Srl
//
// SPDX-License-Identifier: Apache-2.0

import React from "react";
import { MapContainer, TileLayer, Marker, Popup } from "react-leaflet";

export default function Map({ latitude, longitude, popup = "", ...props }) {
  return (
    <MapContainer
      key={`${latitude}-${longitude}`}
      center={[latitude, longitude]}
      zoom={13}
      scrollWheelZoom={true}
      {...props}
    >
      <TileLayer
        attribution='&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors'
        url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
      />
      <Marker position={[latitude, longitude]}>
        {popup && <Popup>{popup}</Popup>}
      </Marker>
    </MapContainer>
  );
}
