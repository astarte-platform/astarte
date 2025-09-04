#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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

defmodule Astarte.Housekeeping.Config do
  @moduledoc false
  use Skogsra

  alias Astarte.DataAccess.Config, as: DataAccessConfig
  alias Astarte.Housekeeping.Config.JWTPublicKeyPEMType

  @envdoc "Enable SSL for the AMQP connection. If not specified, SSL is disabled."
  app_env :amqp_ssl_enabled, :astarte_housekeeping, :amqp_ssl_enabled,
    os_env: "HOUSEKEEPING_AMQP_SSL_ENABLED",
    type: :boolean,
    default: false

  @envdoc """
  Specifies the certificates of the root Certificate Authorities to be trusted for the AMQP connection. When not specified, the bundled cURL certificate bundle will be used.
  """
  app_env :amqp_ssl_ca_file, :astarte_housekeeping, :amqp_ssl_ca_file,
    os_env: "HOUSEKEEPING_AMQP_SSL_CA_FILE",
    type: :binary,
    default: CAStore.file_path()

  @envdoc "Disable Server Name Indication. Defaults to false."
  app_env :amqp_ssl_disable_sni,
          :astarte_housekeeping,
          :amqp_ssl_disable_sni,
          os_env: "HOUSEKEEPING_AMQP_SSL_DISABLE_SNI",
          type: :boolean,
          default: false

  @envdoc "Specify the hostname to be used in TLS Server Name Indication extension. If not specified, the amqp consumer host will be used. This value is used only if Server Name Indication is enabled."
  app_env :amqp_ssl_custom_sni,
          :astarte_housekeeping,
          :amqp_ssl_custom_sni,
          os_env: "HOUSEKEEPING_AMQP_SSL_CUSTOM_SNI",
          type: :binary

  @envdoc "The bind address for the Phoenix server."
  app_env :bind_address, :astarte_housekeeping, :bind_address,
    os_env: "HOUSEKEEPING_API_BIND_ADDRESS",
    type: :binary,
    default: "0.0.0.0"

  @envdoc """
  Disables the authentication. CHANGING IT TO TRUE IS GENERALLY A REALLY BAD IDEA IN A PRODUCTION ENVIRONMENT, IF YOU DON'T KNOW WHAT YOU ARE DOING.
  """
  app_env :disable_authentication, :astarte_housekeeping, :disable_authentication,
    os_env: "HOUSEKEEPING_API_DISABLE_AUTHENTICATION",
    type: :boolean,
    default: false

  @envdoc "The JWT public key."
  app_env :jwt_public_key_pem, :astarte_housekeeping, :jwt_public_key_pem,
    os_env: "HOUSEKEEPING_API_JWT_PUBLIC_KEY_PATH",
    type: JWTPublicKeyPEMType

  @envdoc """
  By default Astarte Housekeeping doesn't support realm deletion. Set this variable to true to
  enable this feature. WARNING: this feature can cause permanent data loss when deleting a realm.
  """
  app_env :enable_realm_deletion, :astarte_housekeeping, :enable_realm_deletion,
    os_env: "HOUSEKEEPING_ENABLE_REALM_DELETION",
    type: :boolean,
    default: false

  @envdoc "Replication strategy for the `astarte` keyspace, either `simple` or `network`. Defaults to `simple`"
  app_env :astarte_keyspace_replication_strategy,
          :astarte_housekeeping,
          :astarte_keyspace_replication_strategy,
          os_env: "HOUSEKEEPING_ASTARTE_KEYSPACE_REPLICATION_STRATEGY",
          type: Astarte.Housekeeping.Config.ReplicationStrategy,
          default: :simple_strategy

  @envdoc "Replication factor for the astarte keyspace, used when simple strategy is used for the astarte keyspace. defaults to 1"
  app_env :astarte_keyspace_replication_factor,
          :astarte_housekeeping,
          :astarte_keyspace_replication_factor,
          os_env: "HOUSEKEEPING_ASTARTE_KEYSPACE_REPLICATION_FACTOR",
          type: :integer,
          default: 1

  @envdoc "Replication map for the astarte keyspace, used when network topology strategy is used for the astarte keyspace."
  app_env :astarte_keyspace_network_replication_map,
          :astarte_housekeeping,
          :astarte_keyspace_network_replication_map,
          os_env: "HOUSEKEEPING_ASTARTE_KEYSPACE_NETWORK_REPLICATION_MAP",
          type: Astarte.Housekeeping.Config.NetworkReplicationMap

  @envdoc """
  "The handling method for database events. The default is `expose`, which means that the events are exposed trough telemetry. The other possible value, `log`, means that the events are logged instead."
  """
  app_env :database_events_handling_method,
          :astarte_housekeeping,
          :database_events_handling_method,
          os_env: "DATABASE_EVENTS_HANDLING_METHOD",
          type: Astarte.Housekeeping.Config.TelemetryType,
          default: :expose

  @envdoc "The host for the AMQP connection."
  app_env :amqp_host, :astarte_housekeeping, :amqp_host,
    os_env: "HOUSEKEEPING_AMQP_HOST",
    type: :binary,
    env_overrides: [
      prod: [required: true],
      dev: [default: "localhost"],
      test: [default: "localhost"]
    ]

  @envdoc "The port for the AMQP connection."
  app_env :amqp_management_port, :astarte_housekeeping, :amqp_management_port,
    os_env: "HOUSEKEEPING_AMQP_MANAGEMENT_PORT",
    type: :integer,
    default: 15672

  @envdoc "The username for the AMQP connection."
  app_env :amqp_username, :astarte_housekeeping, :amqp_username,
    os_env: "HOUSEKEEPING_AMQP_USERNAME",
    type: :binary,
    default: "guest"

  @envdoc "The password for the AMQP connection."
  app_env :amqp_password, :astarte_housekeeping, :amqp_password,
    os_env: "HOUSEKEEPING_AMQP_PASSWORD",
    type: :binary,
    default: "guest"

  @doc """
  Returns true if the authentication is disabled.
  """
  @spec authentication_disabled?() :: boolean()
  def authentication_disabled? do
    disable_authentication!()
  end

  def amqp_base_url!() do
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

  defp build_ssl_options() do
    [
      cacertfile: amqp_ssl_ca_file!(),
      verify: :verify_peer,
      depth: 10
    ]
    |> populate_sni()
  end

  defp populate_sni(ssl_options) do
    if amqp_ssl_disable_sni!() do
      Keyword.put(ssl_options, :server_name_indication, :disable)
    else
      server_name = amqp_ssl_custom_sni!() || amqp_host!()
      Keyword.put(ssl_options, :server_name_indication, to_charlist(server_name))
    end
  end

  @doc """
  Returns :ok if the JWT key is valid, otherwise raise an exception.
  """
  def validate_jwt_public_key_pem! do
    if authentication_disabled?() do
      :ok
    else
      case jwt_public_key_pem() do
        {:ok, nil} ->
          raise "JWT public key not found, HOUSEKEEPING_API_JWT_PUBLIC_KEY_PATH must be set when authentication is enabled."

        {:ok, _key} ->
          :ok
      end
    end
  end

  @doc """
  Returns :ok if at least one of HOUSEKEEPING_ASTARTE_KEYSPACE_REPLICATION_FACTOR or HOUSEKEEPING_ASTARTE_KEYSPACE_NETWORK_REPLICATION_MAP is valid, based on HOUSEKEEPING_ASTARTE_KEYSPACE_REPLICATION_STRATEGY value.
  """
  def validate_astarte_replication! do
    case astarte_keyspace_replication_strategy!() do
      :simple_strategy -> validate_astarte_replication_factor!()
      :network_topology_strategy -> validate_astarte_replication_map!()
      nil -> raise "Invalid replication strategy set for the astarte keyspace"
    end
  end

  defp validate_astarte_replication_factor! do
    case astarte_keyspace_replication_factor() do
      {:ok, replication_factor} when replication_factor != nil ->
        :ok

      _ ->
        raise "Invalid replication factor for the astarte keyspace with simple replication strategy. Check the values of HOUSEKEEPING_ASTARTE_KEYSPACE_REPLICATION_STRATEGY and HOUSEKEEPING_ASTARTE_KEYSPACE_REPLICATION_FACTOR"
    end
  end

  defp validate_astarte_replication_map! do
    case astarte_keyspace_network_replication_map() do
      {:ok, replication_map} when replication_map != nil ->
        :ok

      _ ->
        raise "Invalid or empty replication map for the astarte keyspace with network topology replication strategy. Check the values of HOUSEKEEPING_ASTARTE_KEYSPACE_REPLICATION_STRATEGY and HOUSEKEEPING_ASTARTE_KEYSPACE_NETWORK_REPLICATION_MAP"
    end
  end

  defdelegate astarte_instance_id!, to: DataAccessConfig
  defdelegate astarte_instance_id, to: DataAccessConfig

  defdelegate xandra_nodes, to: DataAccessConfig
  defdelegate xandra_nodes!, to: DataAccessConfig

  defdelegate xandra_options!, to: DataAccessConfig
end
