#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
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

defmodule Astarte.Housekeeping.Engine do
  require Logger

  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Queries

  def create_realm(
        realm,
        public_key_pem,
        replication_factor,
        device_registration_limit,
        opts \\ []
      ) do
    _ =
      Logger.info(
        "Creating new realm.",
        tag: "create_realm",
        realm: realm,
        replication_factor: replication_factor,
        device_registration_limit: device_registration_limit
      )

    Queries.create_realm(
      realm,
      public_key_pem,
      replication_factor,
      device_registration_limit,
      opts
    )
  end

  def get_health do
    case Queries.check_astarte_health(:quorum) do
      :ok ->
        {:ok, %{status: :ready}}

      {:error, :health_check_bad} ->
        case Queries.check_astarte_health(:one) do
          :ok ->
            {:ok, %{status: :degraded}}

          {:error, :health_check_bad} ->
            {:ok, %{status: :bad}}

          {:error, :database_connection_error} ->
            {:ok, %{status: :error}}
        end

      {:error, :database_connection_error} ->
        {:ok, %{status: :error}}
    end
  end

  def get_realm(realm) do
    Queries.get_realm(realm)
  end

  def delete_realm(realm, opts \\ []) do
    if Config.enable_realm_deletion!() do
      _ = Logger.info("Deleting realm", tag: "delete_realm", realm: realm)

      Queries.delete_realm(realm, opts)
    else
      _ =
        Logger.info("HOUSEKEEPING_ENABLE_REALM_DELETION is disabled, realm will not be deleted.",
          tag: "realm_deletion_disabled",
          realm: realm
        )

      {:error, :realm_deletion_disabled}
    end
  end

  def is_realm_existing(realm) do
    Queries.is_realm_existing(realm)
  end

  def list_realms do
    Queries.list_realms()
  end

  @doc """
  Updates a given realm using the provided values map. Fails if realm does not exists or values are invalid.
  At the moment, only updating the realm jwt_public_key_pem is supported.
  Returns a tuple:
  - either {:ok, updated_realm} where updated_realm is a map describing the realm
  - or {:error, reason} where reason is an atom describing the error.
  """
  @spec update_realm(String.t(), %{:jwt_public_key_pem => String.t(), optional(any()) => any()}) ::
          {:ok, map()}
          | {:error, :invalid_update_parameters}
          | {:error, :realm_not_found}
          | {:error, :update_public_key_fail}
          | {:error, :database_error}
          | {:error, :database_connection_error}
  def update_realm(realm_name, update_attrs) do
    if is_realm_update_valid?(update_attrs) do
      _ = Logger.info("Updating realm #{realm_name}", tag: "realm_update_start")
      do_update_realm(realm_name, update_attrs)
    else
      _ =
        Logger.warn("Rejecting update for realm #{realm_name}", tag: "invalid_update_parameters")

      {:error, :invalid_update_parameters}
    end
  end

  defp do_update_realm(realm_name, update_attrs) do
    %{
      jwt_public_key_pem: new_jwt_public_key_pem
    } = update_attrs

    with realm when is_map(realm) <- Queries.get_realm(realm_name),
         :ok <- update_jwt_public_key_pem(realm_name, new_jwt_public_key_pem) do
      updated_realm =
        if new_jwt_public_key_pem != nil do
          Map.put(realm, :jwt_public_key_pem, new_jwt_public_key_pem)
        else
          realm
        end

      _ = Logger.info("Successful update of realm #{realm_name}", tag: "realm_update_success")

      {:ok, updated_realm}
    end
  end

  defp update_jwt_public_key_pem(_realm_name, nil), do: :ok

  defp update_jwt_public_key_pem(realm_name, new_jwt_public_key_pem) do
    case Queries.update_public_key(realm_name, new_jwt_public_key_pem) do
      {:ok, %Xandra.Void{}} ->
        :ok

      {:error, reason} ->
        _ =
          Logger.warn(
            "Cannot update JWT public key for realm #{realm_name}, error #{inspect(reason)}",
            tag: "update_public_key_fail"
          )

        {:error, :update_public_key_fail}
    end
  end

  defp is_realm_update_valid?(update_attrs) do
    # TODO from ScyllaDB >= 5.3, replication can be altered
    update_valid? =
      update_attrs.replication_factor == nil && update_attrs.replication_class == nil &&
        update_attrs.datacenter_replication_factors == %{}

    unless update_valid? do
      _ =
        Logger.warn("Trying to update replication values for realm",
          tag: "invalid_replication_value_update"
        )
    end

    update_valid?
  end
end
