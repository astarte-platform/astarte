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

defmodule Astarte.Secrets.Config do
  @moduledoc """
  This module contains functions to access the configuration
  """

  use Skogsra

  alias Astarte.Secrets.Config
  alias Astarte.Secrets.Config.AuthenticationMechanism

  @envdoc "The URL to access Vault."
  app_env :bao_url, :astarte_secrets, :bao_url,
    os_env: "ASTARTE_VAULT_URL",
    type: :binary,
    default: "http://localhost:8200"

  @envdoc "Internal variable used to store Vault authentication"
  app_env :bao_authentication, :astarte_secrets, :bao_authentication,
    binding_skip: [:system],
    type: :any

  @envdoc "The mechanism to use for authenticating with Vault"
  app_env :bao_authentication_mechanism, :astarte_secrets, :bao_authentication_mechanism,
    os_env: "ASTARTE_VAULT_AUTHENTICATION_MECHANISM",
    type: AuthenticationMechanism

  @envdoc "Token to authenticate with Vault"
  app_env :bao_token, :astarte_secrets, :bao_token,
    os_env: "ASTARTE_VAULT_TOKEN",
    type: :binary

  @envdoc "Enable SSL for the Vault connection. If not specified, SSL is disabled."
  app_env :bao_ssl_enabled, :astarte_secrets, :bao_ssl_enabled,
    os_env: "ASTARTE_VAULT_SSL_ENABLED",
    type: :boolean,
    default: false

  @envdoc """
  Specifies the certificates of the root Certificate Authorities to be trusted for the Vault connection. When not specified, the bundled cURL certificate bundle will be used.
  """
  app_env :bao_ssl_ca_file, :astarte_secrets, :bao_ssl_ca_file,
    os_env: "ASTARTE_VAULT_SSL_CA_FILE",
    type: :binary,
    default: CAStore.file_path()

  @envdoc "Disable Server Name Indication for Vault. Defaults to false."
  app_env :bao_ssl_disable_sni, :astarte_secrets, :bao_ssl_disable_sni,
    os_env: "ASTARTE_VAULT_SSL_DISABLE_SNI",
    type: :boolean,
    default: false

  @envdoc "Specify the hostname to be used in TLS Server Name Indication extension for Vault. If not specified, the Vault host will be used. This value is used only if Server Name Indication is enabled."
  app_env :bao_ssl_custom_sni, :astarte_secrets, :bao_ssl_custom_sni,
    os_env: "ASTARTE_VAULT_SSL_CUSTOM_SNI",
    type: :binary

  def bao_ssl_options! do
    if Config.bao_ssl_enabled!() do
      build_bao_ssl_options()
    else
      []
    end
  end

  defp build_bao_ssl_options do
    [
      cacertfile: bao_ssl_ca_file!(),
      verify: :verify_peer,
      depth: 10
    ]
    |> populate_bao_sni()
  end

  defp populate_bao_sni(ssl_options) do
    if Config.bao_ssl_disable_sni!() do
      Keyword.put(ssl_options, :server_name_indication, :disable)
    else
      server_name =
        case Config.bao_ssl_custom_sni!() do
          nil ->
            Config.bao_url!()
            |> URI.parse()
            |> Map.fetch!(:host)

          custom_sni ->
            custom_sni
        end

      Keyword.put(ssl_options, :server_name_indication, to_charlist(server_name))
    end
  end

  def init do
    parse_bao_authentication!()
    |> put_bao_authentication()
  end

  defp parse_bao_authentication! do
    case Config.bao_authentication_mechanism!() do
      nil ->
        raise "Vault authentication method not set"

      :token ->
        case Config.bao_token!() do
          nil -> raise "Vault token not set"
          token -> {:token, token}
        end
    end
  end
end
