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

  @envdoc "Replication factor for the astarte keyspace, defaults to 1"
  app_env :astarte_keyspace_replication_factor,
          :astarte_housekeeping,
          :astarte_keyspace_replication_factor,
          os_env: "HOUSEKEEPING_ASTARTE_KEYSPACE_REPLICATION_FACTOR",
          type: :integer,
          default: 1

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

  defdelegate astarte_instance_id!, to: DataAccessConfig
  defdelegate astarte_instance_id, to: DataAccessConfig

  defdelegate xandra_nodes, to: DataAccessConfig
  defdelegate xandra_nodes!, to: DataAccessConfig

  defdelegate xandra_options!, to: DataAccessConfig
end
