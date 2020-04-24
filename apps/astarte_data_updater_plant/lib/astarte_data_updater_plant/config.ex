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

  @type amqp_options ::
          {:username, String.t()}
          | {:password, String.t()}
          | {:virtual_host, String.t()}
          | {:host, String.t()}
          | {:port, integer()}

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
    default: 0

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
      port: amqp_consumer_port!()
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
      port: amqp_producer_port
    ]
  end

  def data_updater_deactivation_interval_ms! do
    device_heartbeat_interval_ms!() * 3
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
end
