#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Astarte.Events.Config do
  @moduledoc """
  This module contains functions to access the configuration.
  """
  use Skogsra
  alias Astarte.DataAccess.Config, as: DataAccessConfig

  @type ssl_option ::
          {:cacertfile, String.t()}
          | {:verify, :verify_peer}
          | {:server_name_indication, charlist() | :disable}
          | {:depth, integer()}
  @type ssl_options :: :none | [ssl_option]

  @type amqp_options ::
          {:username, String.t()}
          | {:password, String.t()}
          | {:virtual_host, String.t()}
          | {:host, String.t()}
          | {:port, integer()}
          | {:ssl_options, ssl_options}
          | {:channels, integer()}
  @envdoc "The host for the AMQP consumer connection."
  app_env(:amqp_host, :astarte_events, :amqp_host,
    os_env: "ASTARTE_EVENTS_PRODUCER_AMQP_HOST",
    type: :binary,
    default: "localhost"
  )

  @envdoc "The username for the AMQP consumer connection."
  app_env(:amqp_username, :astarte_events, :amqp_username,
    os_env: "ASTARTE_EVENTS_PRODUCER_AMQP_USERNAME",
    type: :binary,
    default: "guest"
  )

  @envdoc "The password for the AMQP consumer connection."
  app_env(:amqp_password, :astarte_events, :amqp_password,
    os_env: "ASTARTE_EVENTS_PRODUCER_AMQP_PASSWORD",
    type: :binary,
    default: "guest"
  )

  @envdoc "The virtual_host for the AMQP consumer connection."
  app_env(
    :amqp_virtual_host,
    :astarte_events,
    :amqp_virtual_host,
    os_env: "ASTARTE_EVENTS_PRODUCER_AMQP_VIRTUAL_HOST",
    type: :binary,
    default: "/"
  )

  @envdoc "The port for the AMQP consumer connection."
  app_env(:amqp_port, :astarte_events, :amqp_port,
    os_env: "ASTARTE_EVENTS_PRODUCER_AMQP_PORT",
    type: :integer,
    default: 5672
  )

  @envdoc "The port for the AMQP connection."
  app_env :amqp_management_port, :astarte_housekeeping, :amqp_management_port,
    os_env: "HOUSEKEEPING_AMQP_MANAGEMENT_PORT",
    type: :integer,
    default: 15_672

  @envdoc "Enable SSL for the AMQP consumer connection. If not specified, SSL is disabled."
  app_env(:amqp_ssl_enabled, :astarte_events, :amqp_ssl_enabled,
    os_env: "ASTARTE_EVENTS_PRODUCER_AMQP_SSL_ENABLED",
    type: :boolean,
    default: false
  )

  @envdoc """
  Specifies the certificates of the root Certificate Authorities to be trusted for the AMQP consumer connection. When not specified, the bundled cURL certificate bundle will be used.
  """
  app_env(:amqp_ssl_ca_file, :astarte_events, :amqp_ssl_ca_file,
    os_env: "ASTARTE_EVENTS_PRODUCER_AMQP_SSL_CA_FILE",
    type: :binary
  )

  @envdoc "Disable Server Name Indication. Defaults to false."
  app_env(
    :amqp_ssl_disable_sni,
    :astarte_events,
    :amqp_ssl_disable_sni,
    os_env: "ASTARTE_EVENTS_PRODUCER_AMQP_SSL_DISABLE_SNI",
    type: :boolean,
    default: false
  )

  @envdoc "Specify the hostname to be used in TLS Server Name Indication extension. If not specified, the amqp consumer host will be used. This value is used only if Server Name Indication is enabled."
  app_env(
    :amqp_ssl_custom_sni,
    :astarte_events,
    :amqp_ssl_custom_sni,
    os_env: "ASTARTE_EVENTS_PRODUCER_AMQP_SSL_CUSTOM_SNI",
    type: :binary
  )

  @envdoc "The number of connections to RabbitMQ used to consume data"
  app_env :amqp_connection_number,
          :astarte_events,
          :amqp_connection_number,
          os_env: "ASTARTE_EVENTS_PRODUCER_AMQP_CONNECTION_NUMBER",
          type: :integer,
          default: 10

  @envdoc "The total number of data queues in all the Astarte cluster."
  app_env :data_queue_total_count, :astarte_events, :amqp_data_queue_total_count,
    os_env: "ASTARTE_EVENTS_PRODUCER_AMQP_DATA_QUEUE_TOTAL_COUNT",
    type: :integer,
    default: 128

  @envdoc "The exchange used by the AMQP producer to publish events."
  app_env :amqp_events_exchange_name, :astarte_events, :amqp_events_exchange_name,
    os_env: "ASTARTE_EVENTS_PRODUCER_AMQP_EVENTS_EXCHANGE_NAME",
    type: :binary,
    default: "astarte_events"

  # Since we have one channel per queue, this is not configurable
  def amqp_channels_per_connection_number! do
    ceil(data_queue_total_count!() / amqp_connection_number!())
  end

  @doc """
  Returns the AMQP data consumer connection options
  """
  @spec amqp_options!() :: [amqp_options]
  def amqp_options! do
    [
      host: amqp_host!(),
      port: amqp_port!(),
      username: amqp_username!(),
      password: amqp_password!(),
      virtual_host: amqp_virtual_host!(),
      channel_max: amqp_channels_per_connection_number!()
    ]
    |> populate_consumer_ssl_options()
  end

  def amqp_base_url! do
    if amqp_ssl_enabled!() do
      "https://#{amqp_host!()}:#{amqp_management_port!()}"
    else
      "http://#{amqp_host!()}:#{amqp_management_port!()}"
    end
  end

  def ssl_options! do
    if amqp_ssl_enabled!() do
      build_ssl_options()
    else
      []
    end
  end

  defp build_ssl_options do
    [
      cacertfile: amqp_ssl_ca_file!(),
      verify: :verify_peer,
      depth: 10
    ]
    |> populate_sni()
  end

  defp populate_consumer_ssl_options(options) do
    if amqp_ssl_enabled!() do
      ssl_options = build_consumer_ssl_options()
      Keyword.put(options, :ssl_options, ssl_options)
    else
      options
    end
  end

  defp populate_sni(ssl_options) do
    if amqp_ssl_disable_sni!() do
      Keyword.put(ssl_options, :server_name_indication, :disable)
    else
      server_name = amqp_ssl_custom_sni!() || amqp_host!()
      Keyword.put(ssl_options, :server_name_indication, to_charlist(server_name))
    end
  end

  defp build_consumer_ssl_options do
    [
      cacertfile: amqp_ssl_ca_file!() || CAStore.file_path(),
      verify: :verify_peer,
      depth: 10
    ]
    |> populate_consumer_sni()
  end

  defp populate_consumer_sni(ssl_options) do
    if amqp_ssl_disable_sni!() do
      Keyword.put(ssl_options, :server_name_indication, :disable)
    else
      server_name = amqp_ssl_custom_sni!() || amqp_host!()
      Keyword.put(ssl_options, :server_name_indication, to_charlist(server_name))
    end
  end

  # Since we have only one producer, this is not configurable
  def events_connection_number!, do: 1

  def events_pool_config! do
    [
      name: {:local, :events_producer_pool},
      worker_module: ExRabbitPool.Worker.RabbitConnection,
      size: events_connection_number!(),
      max_overflow: 0
    ]
  end

  defdelegate astarte_instance_id!, to: DataAccessConfig
  defdelegate astarte_instance_id, to: DataAccessConfig
  defdelegate xandra_options!, to: DataAccessConfig
end
