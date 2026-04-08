#
# This file is part of Astarte.
#
# Copyright 2017-2025 SECO Mind Srl
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

defmodule Astarte.Pairing.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """

  use Skogsra

  alias Astarte.Pairing.CFSSLCredentials
  alias Astarte.Pairing.Config.BaseURLProtocol
  alias Astarte.Pairing.Config.CQExNodes

  @envdoc "The external broker URL which should be used by devices."
  app_env :broker_url, :astarte_pairing, :broker_url,
    os_env: "PAIRING_BROKER_URL",
    type: :binary,
    required: true

  @envdoc """
  Set this variable to 'true' to enable FDO feature as device authentication mechanism.
  WARNING: this feature is experimental and is not enabled by default
  """
  app_env :enable_fdo, :astarte_pairing, :enable_fdo,
    os_env: "PAIRING_ENABLE_FDO",
    type: :boolean,
    default: false

  @envdoc "The port the ingress is listening on, used for FDO authentication mechanism"
  app_env :base_url_port, :astarte_pairing, :base_url_port,
    os_env: "ASTARTE_BASE_URL_PORT",
    type: :integer

  @envdoc "The protocol the ingress is listening on, used for FDO authentication mechanism"
  app_env :base_url_protocol, :astarte_pairing, :base_url_protocol,
    os_env: "ASTARTE_BASE_URL_PROTOCOL",
    type: BaseURLProtocol

  @envdoc "The astarte base domain, used for FDO authentication mechanism"
  app_env :base_url_domain, :astarte_pairing, :base_url_domain,
    os_env: "ASTARTE_BASE_URL_DOMAIN",
    type: :binary

  @envdoc "URL to the running CFSSL instance for device certificate generation."
  app_env :cfssl_url, :astarte_pairing, :cfssl_url,
    os_env: "PAIRING_CFSSL_URL",
    type: :binary,
    default: "http://localhost:8888"

  @envdoc "The CA certificate."
  app_env :ca_cert, :astarte_pairing, :ca_cert,
    os_env: "PAIRING_CA_CERT",
    type: :binary

  @envdoc "A list of {host, port} values of accessible Cassandra nodes in a cqex compliant format"
  app_env :cqex_nodes, :astarte_pairing, :cqex_nodes,
    os_env: "CASSANDRA_NODES",
    type: CQExNodes,
    default: [{"localhost", 9042}]

  @envdoc "The URL to access the FDO Rendezvous Server."
  app_env :fdo_rendezvous_url, :astarte_pairing, :fdo_rendezvous_url,
    os_env: "PAIRING_FDO_RENDEZVOUS_URL",
    type: :binary,
    default: "http://rendezvous:8041"

  @envdoc "Enable SSL for the FDO Rendezvous Server connection. If not specified, SSL is disabled."
  app_env :fdo_rendezvous_ssl_enabled, :astarte_pairing, :fdo_rendezvous_ssl_enabled,
    os_env: "PAIRING_FDO_RENDEZVOUS_SSL_ENABLED",
    type: :boolean,
    default: false

  @envdoc "Path to the CA certificate file for the FDO Rendezvous Server TLS connection. When not specified, the bundled cURL certificate bundle will be used."
  app_env :fdo_rendezvous_ssl_ca_file, :astarte_pairing, :fdo_rendezvous_ssl_ca_file,
    os_env: "PAIRING_FDO_RENDEZVOUS_SSL_CA_FILE",
    type: :binary,
    default: CAStore.file_path()

  @envdoc "Disable FDO Rendezvous Server Name Indication. Defaults to false."
  app_env :fdo_rendezvous_ssl_disable_sni,
          :astarte_pairing,
          :fdo_rendezvous_ssl_disable_sni,
          os_env: "PAIRING_FDO_RENDEZVOUS_SSL_DISABLE_SNI",
          type: :boolean,
          default: false

  @envdoc "Specify the hostname to be used in TLS Server Name Indication extension. If not specified, the FDO Rendezvous Server host will be used. This value is used only if Server Name Indication is enabled."
  app_env :fdo_rendezvous_ssl_custom_sni, :astarte_pairing, :fdo_rendezvous_ssl_custom_sni,
    os_env: "PAIRING_FDO_RENDEZVOUS_SSL_CUSTOM_SNI",
    type: :binary

  @doc """
  Returns the SSL options for the FDO Rendezvous Server HTTP client.
  Returns an empty list if SSL is disabled.
  """
  def fdo_rendezvous_ssl_options! do
    if fdo_rendezvous_ssl_enabled!() do
      build_rendezvous_ssl_options()
    else
      []
    end
  end

  defp build_rendezvous_ssl_options do
    [
      cacertfile: fdo_rendezvous_ssl_ca_file!(),
      verify: :verify_peer,
      depth: 10
    ]
    |> populate_rendezvous_sni()
  end

  defp populate_rendezvous_sni(ssl_options) do
    if fdo_rendezvous_ssl_disable_sni!() do
      Keyword.put(ssl_options, :server_name_indication, :disable)
    else
      server_name =
        case fdo_rendezvous_ssl_custom_sni!() do
          nil ->
            fdo_rendezvous_url!()
            |> URI.parse()
            |> Map.fetch!(:host)

          custom_sni ->
            custom_sni
        end

      Keyword.put(ssl_options, :server_name_indication, to_charlist(server_name))
    end
  end

  def init! do
    if {:ok, nil} == ca_cert() do
      case CFSSLCredentials.ca_cert() do
        {:ok, cert} ->
          put_ca_cert(cert)

        {:error, _reason} ->
          raise "No CA certificate available."
      end
    end

    if enable_fdo!() do
      # check that all mandatory FDO variables are configured before starting
      variables_to_check = [:base_url_port, :base_url_protocol, :base_url_domain]

      if !Enum.all?(variables_to_check, &variable_set?(&1)) do
        raise "FDO feature is enabled but not all its parameters are configured"
      end
    end
  end

  @envdoc """
  Disables JWT authentication for agent's endpoints. CHANGING IT TO TRUE IS GENERALLY A REALLY BAD IDEA IN A PRODUCTION ENVIRONMENT, IF YOU DON'T KNOW WHAT YOU ARE DOING.
  """
  app_env :disable_authentication, :astarte_pairing, :disable_authentication,
    os_env: "PAIRING_API_DISABLE_AUTHENTICATION",
    type: :boolean,
    default: false

  @envdoc """
  "The handling method for database events. The default is `expose`, which means that the events are exposed trough telemetry. The other possible value, `log`, means that the events are logged instead."
  """
  app_env :database_events_handling_method,
          :astarte_realm_management,
          :database_events_handling_method,
          os_env: "DATABASE_EVENTS_HANDLING_METHOD",
          type: Astarte.Pairing.Config.TelemetryType,
          default: :expose

  @envdoc """
  "set the name for the triggers cache, used for caching triggers and avoid constant db access, defaults to 'trigger_cache'"
  """
  app_env :trigger_cache_name, :astarte_pairing, :trigger_cache_name,
    type: :atom,
    default: :trigger_cache

  @doc """
  Returns the cassandra node configuration
  """
  @spec cassandra_node!() :: {String.t(), integer()}
  def cassandra_node!, do: Enum.random(cqex_nodes!())

  def base_url! do
    protocol = base_url_protocol!()
    domain = base_url_domain!()
    port = base_url_port!()

    "#{protocol}://#{domain}:#{port}"
  end

  @doc """
  Returns true if the authentication for the agent is disabled.
  Credential requests made by devices are always authenticated, even it this is true.
  """
  def authentication_disabled?, do: disable_authentication!()

  defp variable_set?(var_name) do
    case apply(__MODULE__, var_name, []) do
      {:ok, val} when not is_nil(val) ->
        true

      _ ->
        false
    end
  end
end
