#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.Housekeeping.API.Config do
  alias Astarte.Housekeeping.API.Config.JWTPublicKeyPEMType

  use Skogsra

  @envdoc "The bind address for the Phoenix server."
  app_env :bind_address, :astarte_housekeeping_api, :bind_address,
    os_env: "HOUSEKEEPING_API_BIND_ADDRESS",
    type: :binary,
    default: "0.0.0.0"

  @envdoc """
  Disables the authentication. CHANGING IT TO TRUE IS GENERALLY A REALLY BAD IDEA IN A PRODUCTION ENVIRONMENT, IF YOU DON'T KNOW WHAT YOU ARE DOING.
  """
  app_env :disable_authentication, :astarte_housekeeping_api, :disable_authentication,
    os_env: "HOUSEKEEPING_API_DISABLE_AUTHENTICATION",
    type: :binary,
    default: false

  @envdoc "The JWT public key."
  app_env :jwt_public_key_pem, :astarte_housekeeping_api, :jwt_public_key_pem,
    os_env: "HOUSEKEEPING_API_JWT_PUBLIC_KEY_PATH",
    type: JWTPublicKeyPEMType

  @doc "The RPC client module."
  app_env :rpc_client, :astarte_housekeeping_api, :rpc_client,
    os_env: "HOUSEKEEPING_API_RPC_CLIENT",
    binding_skip: [:system],
    type: :unsafe_module,
    default: Astarte.RPC.AMQP.Client

  @envdoc """
  Timeout for RPC calls to Housekeeping backend, in milliseconds.
  """
  app_env :rpc_timeout, :astarte_housekeeping_api, :rpc_timeout,
    os_env: "HOUSEKEEPING_API_RPC_TIMEOUT",
    type: :integer,
    default: 5000

  @doc """
  Returns true if the authentication is disabled.
  """
  @spec authentication_disabled?() :: boolean()
  def authentication_disabled? do
    disable_authentication!()
  end

  @doc """
  Returns :ok if the JWT key is valid, otherwise raise an exception.
  """
  def validate_jwt_public_key_pem!() do
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
end
