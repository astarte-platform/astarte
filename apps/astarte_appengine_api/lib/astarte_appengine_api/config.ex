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

defmodule Astarte.AppEngine.API.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """

  alias Astarte.DataAccess.Config, as: DataAccessConfig
  alias Astarte.AppEngine.API.Config.NonNegativeInteger

  use Skogsra

  @envdoc """
  The max number of data points returned by AppEngine API with a single call. Defaults to 10000. If <= 0, 0 is returned and results are unlimited.
  """
  app_env :max_results_limit, :astarte_appengine_api, :max_results_limit,
    os_env: "APPENGINE_API_MAX_RESULTS_LIMIT",
    type: NonNegativeInteger,
    default: 10000

  @envdoc "If true, HTTP compression will be enabled."
  app_env :enable_compression, :astarte_appengine_api, :enable_compression,
    os_env: "APPENGINE_API_ENABLE_COMPRESSION",
    type: :boolean,
    default: false

  @envdoc "The host for the AMQP consumer connection."
  app_env :rooms_amqp_client_host, :astarte_appengine_api, :rooms_amqp_client_host,
    os_env: "APPENGINE_API_ROOMS_AMQP_CLIENT_HOST",
    type: :binary,
    default: "localhost"

  @envdoc "The username for the AMQP consumer connection."
  app_env :rooms_amqp_client_username, :astarte_appengine_api, :rooms_amqp_client_username,
    os_env: "APPENGINE_API_ROOMS_AMQP_CLIENT_USERNAME",
    type: :binary,
    default: "guest"

  @envdoc "The password for the AMQP consumer connection."
  app_env :rooms_amqp_client_password, :astarte_appengine_api, :rooms_amqp_client_password,
    os_env: "APPENGINE_API_ROOMS_AMQP_CLIENT_PASSWORD",
    type: :binary,
    default: "guest"

  @envdoc "The virtual_host for the AMQP consumer connection."
  app_env :rooms_amqp_client_virtual_host,
          :astarte_appengine_api,
          :rooms_amqp_client_virtual_host,
          os_env: "APPENGINE_API_ROOMS_AMQP_CLIENT_VIRTUAL_HOST",
          type: :binary,
          default: "/"

  @envdoc "The port for the AMQP consumer connection."
  app_env :rooms_amqp_client_port, :astarte_appengine_api, :rooms_amqp_client_port,
    os_env: "APPENGINE_API_ROOMS_AMQP_CLIENT_PORT",
    type: :integer,
    default: 5672

  @envdoc """
  Disables the authentication. CHANGING IT TO TRUE IS GENERALLY A REALLY BAD IDEA IN A PRODUCTION ENVIRONMENT, IF YOU DON'T KNOW WHAT YOU ARE DOING.
  """
  app_env :disable_authentication, :astarte_appengine_api, :disable_authentication,
    os_env: "APPENGINE_API_DISABLE_AUTHENTICATION",
    type: :boolean,
    default: false

  @envdoc "Whether to install Swagger UI and expose API documentation on /swagger."
  app_env :swagger_ui, :astarte_appengine_api, :swagger_ui,
    os_env: "SWAGGER_UI",
    type: :boolean,
    default: true

  @envdoc "The exchange name which Rooms AMQP events consumer binds to."
  app_env :events_exchange_name, :astarte_appengine_api, :events_exchange_name,
    os_env: "APPENGINE_API_ROOMS_EVENTS_EXCHANGE_NAME",
    type: :binary,
    default: "astarte_events"

  @envdoc "The queue name used for Rooms AMQP events consumer."
  app_env :rooms_events_queue_name, :astarte_appengine_api, :rooms_events_queue_name,
    os_env: "APPENGINE_API_ROOMS_EVENTS_QUEUE_NAME",
    type: :binary,
    default: "astarte_rooms_events"

  @envdoc "Returns the RPC client, defaulting to AMQP.Client. Used for Mox during testing."
  app_env :rpc_client, :astarte_appengine_api, :rpc_client,
    os_env: "APPENGINE_API_RPC_CLIENT",
    binding_skip: [:system],
    type: :module,
    default: Astarte.RPC.AMQP.Client

  @doc """
  Returns the routing key used for Rooms AMQP events consumer. A constant for now.
  """
  @spec rooms_events_routing_key!() :: String.t()
  def rooms_events_routing_key! do
    "astarte_rooms"
  end

  @doc """
  Returns true if the authentication is disabled.
  """
  @spec authentication_disabled?() :: boolean()
  def authentication_disabled?, do: disable_authentication!()

  @doc """
  Returns the AMQP connection options for AMQP client consuming events for rooms.
  Defaults to []
  """
  @type options ::
          {:username, String.t()}
          | {:password, String.t()}
          | {:virtual_host, String.t()}
          | {:host, String.t()}
          | {:port, integer()}
  @spec rooms_amqp_options!() :: [options]
  def rooms_amqp_options! do
    [
      host: rooms_amqp_client_host!(),
      username: rooms_amqp_client_username!(),
      password: rooms_amqp_client_password!(),
      virtual_host: rooms_amqp_client_virtual_host!(),
      port: rooms_amqp_client_port!()
    ]
  end

  @doc """
  Returns cassandra nodes formatted in the Xandra format
  """
  defdelegate xandra_nodes, to: DataAccessConfig
  defdelegate xandra_nodes!, to: DataAccessConfig

  @doc """
  Returns cassandra nodes formatted in the CQEx format
  """
  defdelegate cqex_nodes, to: DataAccessConfig
  defdelegate cqex_nodes!, to: DataAccessConfig
end
