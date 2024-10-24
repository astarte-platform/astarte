#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.DataUpdaterPlant.Config do
  @moduledoc """
  This module handles the configuration of DataUpdaterPlant
  """

  alias Astarte.DataAccess.Config, as: DataAccessConfig
  use Skogsra

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
  app_env :amqp_consumer_host, :astarte_data_updater_plant, :amqp_consumer_host,
    os_env: "DATA_UPDATER_PLANT_AMQP_CONSUMER_HOST",
    type: :binary,
    default: "localhost"

  @envdoc "The username for the AMQP consumer connection."
  app_env :amqp_consumer_username, :astarte_data_updater_plant, :amqp_consumer_username,
    os_env: "DATA_UPDATER_PLANT_AMQP_CONSUMER_USERNAME",
    type: :binary,
    default: "guest"

  @envdoc "The password for the AMQP consumer connection."
  app_env :amqp_consumer_password, :astarte_data_updater_plant, :amqp_consumer_password,
    os_env: "DATA_UPDATER_PLANT_AMQP_CONSUMER_PASSWORD",
    type: :binary,
    default: "guest"

  @envdoc "The virtual_host for the AMQP consumer connection."
  app_env :amqp_consumer_virtual_host, :astarte_data_updater_plant, :amqp_consumer_virtual_host,
    os_env: "DATA_UPDATER_PLANT_AMQP_CONSUMER_VIRTUAL_HOST",
    type: :binary,
    default: "/"

  @envdoc "The port for the AMQP consumer connection."
  app_env :amqp_consumer_port, :astarte_data_updater_plant, :amqp_consumer_port,
    os_env: "DATA_UPDATER_PLANT_AMQP_CONSUMER_PORT",
    type: :integer,
    default: 5672

  @envdoc "Enable SSL for the AMQP consumer connection. If not specified, SSL is disabled."
  app_env :amqp_consumer_ssl_enabled, :astarte_data_updater_plant, :amqp_consumer_ssl_enabled,
    os_env: "DATA_UPDATER_PLANT_AMQP_CONSUMER_SSL_ENABLED",
    type: :boolean,
    default: false

  @envdoc """
  Specifies the certificates of the root Certificate Authorities to be trusted for the AMQP consumer connection. When not specified, the bundled cURL certificate bundle will be used.
  """
  app_env :amqp_consumer_ssl_ca_file, :astarte_data_updater_plant, :amqp_consumer_ssl_ca_file,
    os_env: "DATA_UPDATER_PLANT_AMQP_CONSUMER_SSL_CA_FILE",
    type: :binary

  @envdoc "Disable Server Name Indication. Defaults to false."
  app_env :amqp_consumer_ssl_disable_sni,
          :astarte_data_updater_plant,
          :amqp_consumer_ssl_disable_sni,
          os_env: "DATA_UPDATER_PLANT_AMQP_CONSUMER_SSL_DISABLE_SNI",
          type: :boolean,
          default: false

  @envdoc "Specify the hostname to be used in TLS Server Name Indication extension. If not specified, the amqp consumer host will be used. This value is used only if Server Name Indication is enabled."
  app_env :amqp_consumer_ssl_custom_sni,
          :astarte_data_updater_plant,
          :amqp_consumer_ssl_custom_sni,
          os_env: "DATA_UPDATER_PLANT_AMQP_CONSUMER_SSL_CUSTOM_SNI",
          type: :binary

  @envdoc """
  The host for the AMQP producer connection. If no AMQP producer options are set, the AMQP consumer options will be used.
  """
  app_env :amqp_producer_host, :astarte_data_updater_plant, :amqp_producer_host,
    os_env: "DATA_UPDATER_PLANT_AMQP_PRODUCER_HOST",
    type: :binary

  @envdoc """
  The username for the AMQP producer connection. If no AMQP producer options are set, the AMQP consumer options will be used.
  """
  app_env :amqp_producer_username, :astarte_data_updater_plant, :amqp_producer_username,
    os_env: "DATA_UPDATER_PLANT_AMQP_PRODUCER_USERNAME",
    type: :binary

  @envdoc """
  The password for the AMQP producer connection. If no AMQP producer options are set, the AMQP consumer options will be used.
  """
  app_env :amqp_producer_password, :astarte_data_updater_plant, :amqp_producer_password,
    os_env: "DATA_UPDATER_PLANT_AMQP_PRODUCER_PASSWORD",
    type: :binary

  @envdoc """
  The virtual_host for the AMQP producer connection. If no AMQP producer options are set, the AMQP consumer options will be used.
  """
  app_env :amqp_producer_virtual_host, :astarte_data_updater_plant, :amqp_producer_virtual_host,
    os_env: "DATA_UPDATER_PLANT_AMQP_PRODUCER_VIRTUAL_HOST",
    type: :binary

  @envdoc """
  The port for the AMQP producer connection. If no AMQP producer options are set, the AMQP consumer options will be used.
  """
  app_env :amqp_producer_port, :astarte_data_updater_plant, :amqp_producer_port,
    os_env: "DATA_UPDATER_PLANT_AMQP_PRODUCER_PORT",
    type: :integer

  @envdoc "The exchange used by the AMQP producer to publish events."
  app_env :events_exchange_name, :astarte_data_updater_plant, :amqp_events_exchange_name,
    os_env: "DATA_UPDATER_PLANT_AMQP_EVENTS_EXCHANGE_NAME",
    type: :binary,
    default: "astarte_events"

  @envdoc "Enable SSL for the AMQP producer connection. If not specified, the consumer's setting will be used."
  app_env :amqp_producer_ssl_enabled, :astarte_data_updater_plant, :amqp_producer_ssl_enabled,
    os_env: "DATA_UPDATER_PLANT_AMQP_PRODUCER_SSL_ENABLED",
    type: :boolean

  @envdoc """
  Specifies the certificates of the root Certificate Authorities to be trusted for the AMQP producer connection. When not specified, either the consumer's ca_cert is used (if set), or the bundled cURL certificate bundle will be used.
  """
  app_env :amqp_producer_ssl_ca_file, :astarte_data_updater_plant, :amqp_producer_ssl_ca_file,
    os_env: "DATA_UPDATER_PLANT_AMQP_PRODUCER_SSL_CA_FILE",
    type: :binary

  @envdoc "Disable Server Name Indication. Defaults to false."
  app_env :amqp_producer_ssl_disable_sni,
          :astarte_data_updater_plant,
          :amqp_producer_ssl_disable_sni,
          os_env: "DATA_UPDATER_PLANT_AMQP_PRODUCER_SSL_DISABLE_SNI",
          type: :boolean,
          default: false

  @envdoc "Specify the hostname to be used in TLS Server Name Indication extension. If not specified, the amqp consumer host will be used. This value is used only if Server Name Indication is enabled."
  app_env :amqp_producer_ssl_custom_sni,
          :astarte_data_updater_plant,
          :amqp_producer_ssl_custom_sni,
          os_env: "DATA_UPDATER_PLANT_AMQP_PRODUCER_SSL_CUSTOM_SNI",
          type: :binary

  @envdoc "The prefix used to contruct data queue names, together with queue indexes."
  app_env :data_queue_prefix, :astarte_data_updater_plant, :amqp_data_queue_prefix,
    os_env: "DATA_UPDATER_PLANT_AMQP_DATA_QUEUE_PREFIX",
    type: :binary,
    default: "astarte_data_"

  @envdoc "The first queue index that is handled by this Data Updater Plant instance"
  app_env :data_queue_range_start, :astarte_data_updater_plant, :amqp_data_queue_range_start,
    os_env: "DATA_UPDATER_PLANT_AMQP_DATA_QUEUE_RANGE_START",
    type: :integer,
    default: 0

  @envdoc "The last queue index that is handled by this Data Updater Plant instance"
  app_env :data_queue_range_end, :astarte_data_updater_plant, :amqp_data_queue_range_end,
    os_env: "DATA_UPDATER_PLANT_AMQP_DATA_QUEUE_RANGE_END",
    type: :integer,
    default: 127

  @envdoc "The total number of data queues in all the Astarte cluster."
  app_env :data_queue_total_count, :astarte_data_updater_plant, :amqp_data_queue_total_count,
    os_env: "DATA_UPDATER_PLANT_AMQP_DATA_QUEUE_TOTAL_COUNT",
    type: :integer,
    default: 128

  @envdoc "The prefetch count of the AMQP consumer connection. A prefetch count of 0 means unlimited (not recommended)."
  app_env :consumer_prefetch_count,
          :astarte_data_updater_plant,
          :amqp_consumer_prefetch_count,
          os_env: "DATA_UPDATER_PLANT_AMQP_CONSUMER_PREFETCH_COUNT",
          type: :integer,
          default: 300

  @envdoc "The port where Data Upater Plant metrics will be exposed."
  app_env :port, :astarte_data_updater_plant, :port,
    os_env: "DATA_UPDATER_PLANT_PORT",
    type: :integer,
    default: 4000

  @envdoc """
  The RPC client, defaulting to AMQP.Client. Used for Mox during testing.
  """
  app_env :rpc_client, :astarte_data_updater_plant, :rpc_client,
    os_env: "DATA_UPDATER_PLANT_RPC_CLIENT",
    binding_skip: [:system],
    type: :module,
    default: Astarte.RPC.AMQP.Client

  @envdoc "The interval between two heartbeats sent from the VernqMQ device process."
  app_env :device_heartbeat_interval_ms,
          :astarte_data_updater_plant,
          :device_heartbeat_interval_ms,
          os_env: "DATA_UPDATER_PLANT_DEVICE_HEARTBEAT_INTERVAL_MS",
          type: :integer,
          default: 60 * 60 * 1_000

  @envdoc "Generate incoming_introspection events in the old (pre-1.2) string-based format. Defaults to false."
  app_env :generate_legacy_incoming_introspection_events,
          :astarte_data_updater_plant,
          :generate_legacy_introspection_events,
          os_env: "DATA_UPDATER_PLANT_GENERATE_LEGACY_INCOMING_INTROSPECTION_EVENTS",
          type: :boolean,
          default: false

  @envdoc "The number of connections to RabbitMQ used to consume data"
  app_env :amqp_consumer_connection_number,
          :astarte_data_updater_plant,
          :amqp_consumer_connection_number,
          os_env: "DATA_UPDATER_PLANT_AMQP_CONSUMER_CONNECTION_NUMBER",
          type: :integer,
          default: 10

  # Since we have one channel per queue, this is not configurable
  def amqp_consumer_channels_per_connection_number!() do
    ceil(data_queue_total_count!() / amqp_consumer_connection_number!())
  end

  # Since we have only one producer, this is not configurable
  def events_producer_connection_number!(), do: 1

  # Since we have one channel per queue, this is not configurable
  def events_producer_channels_per_connection_number!(), do: 1

  @doc """
  Returns the AMQP data consumer connection options
  """
  @spec amqp_consumer_options!() :: [amqp_options]
  def amqp_consumer_options! do
    [
      host: amqp_consumer_host!(),
      username: amqp_consumer_username!(),
      password: amqp_consumer_password!(),
      virtual_host: amqp_consumer_virtual_host!(),
      port: amqp_consumer_port!(),
      channels: amqp_consumer_channels_per_connection_number!()
    ]
    |> populate_consumer_ssl_options()
  end

  defp populate_consumer_ssl_options(options) do
    if amqp_consumer_ssl_enabled!() do
      ssl_options = build_consumer_ssl_options()
      Keyword.put(options, :ssl_options, ssl_options)
    else
      options
    end
  end

  defp build_consumer_ssl_options() do
    [
      cacertfile: amqp_consumer_ssl_ca_file!() || CAStore.file_path(),
      verify: :verify_peer,
      depth: 10
    ]
    |> populate_consumer_sni()
  end

  defp populate_consumer_sni(ssl_options) do
    if amqp_consumer_ssl_disable_sni!() do
      Keyword.put(ssl_options, :server_name_indication, :disable)
    else
      server_name = amqp_consumer_ssl_custom_sni!() || amqp_consumer_host!()
      Keyword.put(ssl_options, :server_name_indication, to_charlist(server_name))
    end
  end

  def amqp_consumer_pool_config!() do
    [
      name: {:local, :amqp_consumer_pool},
      worker_module: ExRabbitPool.Worker.RabbitConnection,
      size: amqp_consumer_connection_number!(),
      max_overflow: 0
    ]
  end

  @doc """
  Returns the AMQP trigger producer connection options
  """
  @spec amqp_producer_options!() :: [amqp_options]
  def amqp_producer_options! do
    # if producer options are not explicitly set, use the corresponding consumer option
    amqp_producer_host =
      case amqp_producer_host() do
        {:ok, nil} ->
          amqp_consumer_host!()

        {:ok, host} ->
          host
      end

    amqp_producer_username =
      case amqp_producer_username() do
        {:ok, nil} ->
          amqp_consumer_username!()

        {:ok, username} ->
          username
      end

    amqp_producer_password =
      case amqp_producer_password() do
        {:ok, nil} ->
          amqp_consumer_password!()

        {:ok, password} ->
          password
      end

    amqp_producer_virtual_host =
      case amqp_producer_virtual_host() do
        {:ok, nil} ->
          amqp_consumer_virtual_host!()

        {:ok, virtual_host} ->
          virtual_host
      end

    amqp_producer_port =
      case amqp_producer_port() do
        {:ok, nil} ->
          amqp_consumer_port!()

        {:ok, port} ->
          port
      end

    [
      host: amqp_producer_host,
      username: amqp_producer_username,
      password: amqp_producer_password,
      virtual_host: amqp_producer_virtual_host,
      port: amqp_producer_port,
      channels: events_producer_channels_per_connection_number!()
    ]
    |> populate_producer_ssl_options()
  end

  def amqp_producer_ssl_enabled? do
    case amqp_producer_ssl_enabled() do
      {:ok, nil} ->
        amqp_consumer_ssl_enabled!()

      {:ok, ssl_enabled} ->
        ssl_enabled
    end
  end

  defp populate_producer_ssl_options(options) do
    if amqp_producer_ssl_enabled?() do
      ssl_options = build_producer_ssl_options()
      Keyword.put(options, :ssl_options, ssl_options)
    else
      options
    end
  end

  defp producer_ssl_sni_disabled? do
    case amqp_producer_ssl_disable_sni() do
      {:ok, nil} ->
        amqp_consumer_ssl_disable_sni!()

      {:ok, value} ->
        value
    end
  end

  defp build_producer_ssl_options do
    [
      cacertfile:
        amqp_producer_ssl_ca_file!() || amqp_consumer_ssl_ca_file!() || CAStore.file_path(),
      verify: :verify_peer,
      depth: 10
    ]
    |> populate_producer_sni()
  end

  defp populate_producer_sni(ssl_options) do
    if producer_ssl_sni_disabled?() do
      Keyword.put(ssl_options, :server_name_indication, :disable)
    else
      server_name =
        amqp_producer_ssl_custom_sni!() || amqp_producer_host!() || amqp_consumer_host!()

      Keyword.put(ssl_options, :server_name_indication, to_charlist(server_name))
    end
  end

  def events_producer_pool_config!() do
    [
      name: {:local, :dup_events_producer_pool},
      worker_module: ExRabbitPool.Worker.RabbitConnection,
      size: events_producer_connection_number!(),
      max_overflow: 0
    ]
  end

  def data_updater_deactivation_interval_ms! do
    device_heartbeat_interval_ms!() * 3
  end

  def amqp_adapter!() do
    Application.get_env(:astarte_data_updater_plant, :amqp_adapter)
  end

  @doc """
  Returns Cassandra nodes formatted in the Xandra format.
  """
  defdelegate xandra_nodes, to: DataAccessConfig
  defdelegate xandra_nodes!, to: DataAccessConfig

  @doc """
  Returns Cassandra nodes formatted in the CQEx format.
  """
  defdelegate cqex_nodes, to: DataAccessConfig
  defdelegate cqex_nodes!, to: DataAccessConfig

  defdelegate xandra_options!, to: DataAccessConfig
  defdelegate cqex_options!, to: DataAccessConfig

  defdelegate astarte_instance_id!, to: DataAccessConfig
  defdelegate astarte_instance_id, to: DataAccessConfig
end
