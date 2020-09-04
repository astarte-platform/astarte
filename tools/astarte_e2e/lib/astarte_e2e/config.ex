#
# This file is part of Astarte.
#
# Copyright 2020 Ispirata Srl
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

defmodule AstarteE2E.Config do
  use Skogsra

  alias AstarteE2E.Config.PositiveIntegerOrInfinity

  @envdoc "Astarte Pairing URL."
  app_env :pairing_url, :astarte_e2e, :pairing_url,
    os_env: "ASTARTE_E2E_PAIRING_URL",
    type: :binary,
    required: true

  @envdoc "Device ID."
  app_env :device_id, :astarte_e2e, :device_id,
    os_env: "ASTARTE_E2E_DEVICE_ID",
    type: :binary,
    required: true

  @envdoc "Credentials secret."
  app_env :credentials_secret, :astarte_e2e, :credentials_secret,
    os_env: "ASTARTE_E2E_CREDENTIALS_SECRET",
    type: :binary,
    required: true

  @envdoc "Ignore SSL errors."
  app_env :ignore_ssl_errors, :astarte_e2e, :ignore_ssl_errors,
    os_env: "ASTARTE_E2E_IGNORE_SSL_ERRORS",
    type: :boolean,
    default: false

  @envdoc "Websocket URL."
  app_env :websocket_url, :astarte_e2e, :websocket_url,
    os_env: "ASTARTE_E2E_WEBSOCKET_URL",
    type: :binary,
    required: true

  @envdoc "Realm name."
  app_env :realm, :astarte_e2e, :realm,
    os_env: "ASTARTE_E2E_REALM",
    type: :binary,
    required: true

  @envdoc "Token."
  app_env :token, :astarte_e2e, :token,
    os_env: "ASTARTE_E2E_TOKEN",
    type: :binary,
    required: true

  @envdoc "Time interval between consecutive checks (in seconds)."
  app_env :check_interval_s, :astarte_e2e, :check_interval_s,
    os_env: "ASTARTE_E2E_CHECK_INTERVAL_SECONDS",
    type: :integer,
    default: 60

  @envdoc "Overall number of consistency checks repetitions. Defaults to 0, corresponding to endless checks."
  app_env :check_repetitions, :astarte_e2e, :check_repetitions,
    os_env: "ASTARTE_E2E_CHECK_REPETITIONS",
    type: PositiveIntegerOrInfinity,
    default: :infinity

  def astarte_e2e_opts! do
    [
      pairing_url: pairing_url!(),
      device_id: device_id!(),
      credentials_secret: credentials_secret!(),
      ignore_ssl_errors: ignore_ssl_errors!(),
      url: websocket_url!(),
      realm: realm!(),
      token: token!(),
      check_interval_s: check_interval_s!(),
      check_repetitions: check_repetitions!()
    ]
  end
end
