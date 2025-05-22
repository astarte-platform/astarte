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

  @envdoc "Enable SSL. If not specified SSL is disabled."
  app_env :rooms_amqp_client_ssl_enabled,
          :astarte_appengine_api,
          :rooms_amqp_client_ssl_enabled,
          os_env: "APPENGINE_API_ROOMS_AMQP_CLIENT_SSL_ENABLED",
          type: :boolean,
          default: false

  @envdoc "Specifies the certificates of the root Certificate Authorities to be trusted. When not specified, the bundled cURL certificate bundle will be used."
  app_env :rooms_amqp_client_ssl_ca_file,
          :astarte_appengine_api,
          :rooms_amqp_client_ssl_ca_file,
          os_env: "APPENGINE_API_ROOMS_AMQP_CLIENT_SSL_CA_FILE",
          type: :binary

  @envdoc "Disable Server Name Indication. Defaults to false."
  app_env :rooms_amqp_client_ssl_disable_sni,
          :astarte_appengine_api,
          :rooms_amqp_client_ssl_disable_sni,
          os_env: "APPENGINE_API_ROOMS_AMQP_CLIENT_SSL_DISABLE_SNI",
          type: :boolean,
          default: false

  @envdoc "Specify the hostname to be used in TLS Server Name Indication extension. If not specified, the amqp host will be used. This value is used only if Server Name Indication is enabled."
  app_env :rooms_amqp_client_ssl_custom_sni,
          :astarte_appengine_api,
          :rooms_amqp_client_ssl_custom_sni,
          os_env: "APPENGINE_API_ROOMS_AMQP_CLIENT_SSL_CUSTOM_SNI",
          type: :binary

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
  @type ssl_option ::
          {:cacertfile, String.t()}
          | {:verify, :verify_peer}
          | {:server_name_indication, :disable | charlist()}
          | {:depth, integer()}
  @type ssl_options :: :none | [ssl_option]

  @type options ::
          {:username, String.t()}
          | {:password, String.t()}
          | {:virtual_host, String.t()}
          | {:host, String.t()}
          | {:port, integer()}
          | {:ssl_options, ssl_options}

  @spec rooms_amqp_options!() :: [options]
  def rooms_amqp_options! do
    [
      host: rooms_amqp_client_host!(),
      username: rooms_amqp_client_username!(),
      password: rooms_amqp_client_password!(),
      virtual_host: rooms_amqp_client_virtual_host!(),
      port: rooms_amqp_client_port!()
    ]
    |> populate_ssl_options()
  end

  defp populate_ssl_options(options) do
    if rooms_amqp_client_ssl_enabled!() do
      ssl_options = build_ssl_options()
      Keyword.put(options, :ssl_options, ssl_options)
    else
      options
    end
  end

  defp build_ssl_options() do
    [
      cacertfile: rooms_amqp_client_ssl_ca_file!() || CAStore.file_path(),
      verify: :verify_peer,
      depth: 10
    ]
    |> populate_sni()
  end

  defp populate_sni(ssl_options) do
    if rooms_amqp_client_ssl_disable_sni!() do
      Keyword.put(ssl_options, :server_name_indication, :disable)
    else
      server_name = rooms_amqp_client_ssl_custom_sni!() || rooms_amqp_client_host!()
      Keyword.put(ssl_options, :server_name_indication, to_charlist(server_name))
    end
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

  defdelegate xandra_options!, to: DataAccessConfig

  defdelegate astarte_instance_id!, to: DataAccessConfig
  defdelegate astarte_instance_id, to: DataAccessConfig
end
