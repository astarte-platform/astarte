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

  use Astarte.Config

  alias Astarte.Secrets.Config
  alias Astarte.Secrets.Config.AuthenticationMechanism

  url_env :vault, :astarte_secrets, :vault, env_app: "ASTARTE", default_port: 8200

  @envdoc "Internal variable used to store Vault authentication"
  app_env :vault_authentication, :astarte_secrets, :vault_authentication,
    binding_skip: [:system],
    type: :any

  @envdoc "The mechanism to use for authenticating with Vault"
  app_env :vault_authentication_mechanism, :astarte_secrets, :vault_authentication_mechanism,
    os_env: "ASTARTE_VAULT_AUTHENTICATION_MECHANISM",
    type: AuthenticationMechanism

  @envdoc "Token to authenticate with Vault"
  app_env :vault_token, :astarte_secrets, :vault_token,
    os_env: "ASTARTE_VAULT_TOKEN",
    type: :binary

  @envdoc "Base namespace in which to create all subnamespaces"
  app_env :vault_base_namespace, :astarte_secrets, :vault_base_namespace,
    os_env: "ASTARTE_VAULT_BASE_NAMESPACE",
    type: :binary,
    default: "/"

  def init do
    parse_vault_authentication!()
    |> put_vault_authentication()
  end

  defp parse_vault_authentication! do
    case Config.vault_authentication_mechanism!() do
      nil ->
        raise "Vault authentication method not set"

      :token ->
        case Config.vault_token!() do
          nil -> raise "Vault token not set"
          token -> {:token, token}
        end
    end
  end
end
