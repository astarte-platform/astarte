#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
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

defmodule Astarte.Pairing.APIWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :astarte_pairing_api

  plug RemoteIp

  socket "/socket", Astarte.Pairing.APIWeb.UserSocket, websocket: true

  # Serve at "/" the static files from "priv/static" directory.
  #
  # You should set gzip to true if you are running phoenix.digest
  # when deploying your static files in production.
  plug Plug.Static,
    at: "/",
    from: :astarte_pairing_api,
    gzip: false,
    only: ~w(css fonts images js favicon.ico robots.txt)

  # Code reloading can be explicitly enabled under the
  # :code_reloader configuration of your endpoint.
  if code_reloading? do
    plug Phoenix.CodeReloader
  end

  plug Plug.RequestId
  plug CORSPlug
  plug Astarte.Pairing.APIWeb.HealthPlug
  plug Astarte.Pairing.APIWeb.MetricsPlug
  plug PlugLoggerWithMeta
  plug Plug.Telemetry, event_prefix: [:phoenix, :endpoint]

  plug Plug.Parsers,
    parsers: [:json],
    json_decoder: Phoenix.json_library()

  plug Plug.MethodOverride
  plug Plug.Head

  # The session will be stored in the cookie and signed,
  # this means its contents can be read but not tampered with.
  # Set :encryption_salt if you would also like to encrypt it.
  plug Plug.Session,
    store: :cookie,
    key: "_astarte_pairing_api_key",
    signing_salt: "M/HFhRJn"

  plug Astarte.Pairing.APIWeb.Router
end
