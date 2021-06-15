#
# This file is part of Astarte.
#
# Copyright 2021 Ispirata Srl
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

defmodule AstarteDeviceFleetSimulator.Config do
  use Skogsra
  require Logger

  @type scheduler_option ::
          {:device_count_s, integer()}
          | {:test_duration_s, integer()}
          | {:spawn_interval_s, integer()}

  @type message_option ::
          {:path, binary()}
          | {:value, float()}
          | {:qos, integer()}

  @type device_options :: Astarte.Device.device_options()
  @type scheduler_options :: [scheduler_option()]
  @type message_options :: [message_option()]

  @envdoc "Astarte Pairing URL (e.g. https://api.astarte.example.com/pairing)."
  app_env(:pairing_url, :astarte_device_fleet_simulator, :pairing_url,
    os_env: "DEVICE_FLEET_PAIRING_URL",
    type: :binary,
    required: true
  )

  @envdoc "Ignore SSL errors. Defaults to false. Changing the value to true is not advised for production environments unless you're aware of what you're doing."
  app_env(:ignore_ssl_errors, :astarte_device_fleet_simulator, :ignore_ssl_errors,
    os_env: "DEVICE_FLEET_IGNORE_SSL_ERRORS",
    type: :boolean,
    default: false
  )

  @envdoc "Astarte Broker URL (e.g. https://broker.astarte.example.com/)."
  app_env(:broker_url, :astarte_device_fleet_simulator, :broker_url,
    os_env: "DEVICE_FLEET_BROKER_URL",
    type: :binary,
    required: true
  )

  @envdoc "Realm name."
  app_env(:realm, :astarte_device_fleet_simulator, :realm,
    os_env: "DEVICE_FLEET_REALM",
    type: :binary,
    required: true
  )

  @envdoc "The Astarte JWT employed to access Astarte APIs. The token can be generated with: `$ astartectl utils gen-jwt <service> -k <your-private-key>.pem`."
  app_env(:jwt, :astarte_device_fleet_simulator, :jwt,
    os_env: "DEVICE_FLEET_JWT",
    type: :binary,
    required: true
  )

  @envdoc "Time interval between consecutive spawns of Astarte devices (in seconds)."
  app_env(:spawn_interval_s, :astarte_device_fleet_simulator, :spawn_interval_s,
    os_env: "DEVICE_FLEET_SPAWN_INTERVAL_SECONDS",
    type: :pos_integer,
    default: 1
  )

  @envdoc "Time interval between messages from a single Astarte devices (in milliseconds)."
  app_env(:publication_interval_ms, :astarte_device_fleet_simulator, :publication_interval_ms,
    os_env: "DEVICE_FLEET_PUBLICATION_INTERVAL_MILLISECONDS",
    type: :integer,
    default: 1000
  )

  @envdoc "The number of Astarte device forming a test fleet."
  app_env(:device_count, :astarte_device_fleet_simulator, :device_count,
    os_env: "DEVICE_FLEET_DEVICE_COUNT",
    type: :pos_integer,
    default: 10
  )

  @envdoc "The length of the test (in seconds)."
  app_env(:test_duration_s, :astarte_device_fleet_simulator, :test_duration_s,
    os_env: "DEVICE_FLEET_TEST_DURATION",
    type: :pos_integer,
    default: 10
  )

  @envdoc "The path of the interface to which data are sent."
  app_env(:path, :astarte_device_fleet_simulator, :path,
    os_env: "DEVICE_FLEET_PATH",
    type: :binary,
    default: "/streamTest/value"
  )

  @envdoc "The value to send."
  app_env(:value, :astarte_device_fleet_simulator, :value,
    os_env: "DEVICE_FLEET_VALUE",
    type: :float,
    default: 0.3
  )

  @envdoc "The QoS mode for messages sent from Astarte devices."
  app_env(:qos, :astarte_device_fleet_simulator, :qos,
    os_env: "DEVICE_FLEET_QOS",
    type: :pos_integer,
    default: 2
  )

  defp generate_websocket_url(appengine_url) do
    cond do
      String.starts_with?(appengine_url, "https://") ->
        String.replace_prefix(appengine_url, "https://", "wss://")

      String.starts_with?(appengine_url, "http://") ->
        String.replace_prefix(appengine_url, "http://", "ws://")

      true ->
        ""
    end
    |> String.trim("/")
  end

  @spec device_opts() :: device_options()
  def device_opts do
    [
      pairing_url: pairing_url!(),
      realm: realm!(),
      interface_provider: standard_interface_provider!(),
      ignore_ssl_errors: ignore_ssl_errors!()
    ]
  end

  @spec scheduler_opts() :: scheduler_options()
  def scheduler_opts do
    [
      device_count: device_count!(),
      test_duration_s: test_duration_s!() * 1000,
      spawn_interval_s: spawn_interval_s!() * 1000
    ]
  end

  @spec message_opts() :: message_options()
  def message_opts do
    [
      path: path!(),
      value: value!(),
      qos: qos!()
    ]
  end

  @spec standard_interface_provider() :: {:ok, String.t()}
  def standard_interface_provider do
    {:ok, standard_interface_provider!()}
  end

  @spec standard_interface_provider!() :: String.t()
  def standard_interface_provider! do
    :code.priv_dir(:astarte_device_fleet_simulator)
    |> Path.join("interfaces")
  end
end
