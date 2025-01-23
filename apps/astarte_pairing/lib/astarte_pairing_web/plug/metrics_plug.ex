# Copyright 2017-2020 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.PairingWeb.MetricsPlug do
  import Plug.Conn

  def init(_args), do: nil

  def call(%{request_path: "/metrics", method: "GET"} = conn, _opts) do
    metrics = TelemetryMetricsPrometheus.Core.scrape()

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, metrics)
    |> halt()
  end

  def call(conn, _opts), do: conn
end
