#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.FDO.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """

  use Skogsra

  alias Astarte.FDO.Config.BaseURLProtocol

  @envdoc "The port the ingress is listening on, used for FDO authentication mechanism"
  app_env :base_url_port, :astarte_fdo, :base_url_port,
    os_env: "ASTARTE_BASE_URL_PORT",
    type: :integer,
    required: true

  @envdoc "The protocol the ingress is listening on, used for FDO authentication mechanism"
  app_env :base_url_protocol, :astarte_fdo, :base_url_protocol,
    os_env: "ASTARTE_BASE_URL_PROTOCOL",
    type: BaseURLProtocol,
    required: true

  @envdoc "The astarte base domain, used for FDO authentication mechanism"
  app_env :base_url_domain, :astarte_fdo, :base_url_domain,
    os_env: "ASTARTE_BASE_URL_DOMAIN",
    type: :binary,
    required: true

  @envdoc "The FDO Rendezvous Server URL"
  app_env :fdo_rendezvous_url, :astarte_fdo, :fdo_rendezvous_url,
    os_env: "PAIRING_FDO_RENDEZVOUS_URL",
    type: :binary,
    default: "http://rendezvous:8041"

  @envdoc "Enable SSL for the FDO Rendezvous Server connection. If not specified, SSL is disabled."
  app_env :fdo_rendezvous_ssl_enabled, :astarte_fdo, :fdo_rendezvous_ssl_enabled,
    os_env: "PAIRING_FDO_RENDEZVOUS_SSL_ENABLED",
    type: :boolean,
    default: false

  @envdoc "Path to the CA certificate file for the FDO Rendezvous Server TLS connection. When not specified, the bundled cURL certificate bundle will be used."
  app_env :fdo_rendezvous_ssl_ca_file, :astarte_fdo, :fdo_rendezvous_ssl_ca_file,
    os_env: "PAIRING_FDO_RENDEZVOUS_SSL_CA_FILE",
    type: :binary,
    default: CAStore.file_path()

  @envdoc "Disable FDO Rendezvous Server Name Indication. Defaults to false."
  app_env :fdo_rendezvous_ssl_disable_sni, :astarte_fdo, :fdo_rendezvous_ssl_disable_sni,
    os_env: "PAIRING_FDO_RENDEZVOUS_SSL_DISABLE_SNI",
    type: :boolean,
    default: false

  @envdoc "Specify the hostname to be used in TLS Server Name Indication extension. If not specified, the FDO Rendezvous Server host will be used. This value is used only if Server Name Indication is enabled."
  app_env :fdo_rendezvous_ssl_custom_sni, :astarte_fdo, :fdo_rendezvous_ssl_custom_sni,
    os_env: "PAIRING_FDO_RENDEZVOUS_SSL_CUSTOM_SNI",
    type: :binary

  @envdoc "Endpoint module to use for FDO session tokens (must have secret_key_base configured)"
  app_env :fdo_session_endpoint, :astarte_fdo, :endpoint,
    os_env: "FDO_SESSION_ENDPOINT",
    type: :atom

  def init! do
    # check that all mandatory FDO variables are configured before starting
    __MODULE__.validate!()
  end

  def base_url! do
    protocol = __MODULE__.base_url_protocol!()
    domain = __MODULE__.base_url_domain!()
    port = __MODULE__.base_url_port!()

    "#{protocol}://#{domain}:#{port}"
  end

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
end
