#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.RealmManagement.API.RealmConfig.Queries do
  @moduledoc """
  Queries to handle JWT public keys retrieval and update.
  """
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  import Ecto.Query

  require Logger

  @doc """
  Gets the jwt public key pem for the realm with name `realm_name`. returns
  {:error, :public_key_not_found} if the realm could not be found.
  """
  @spec fetch_jwt_public_key_pem(String.t()) ::
          {:ok, String.t()} | {:error, :public_key_not_found}
  def fetch_jwt_public_key_pem(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    consistency = Consistency.domain_model(:read)

    KvStore.fetch_value("auth", "jwt_public_key_pem", :string,
      prefix: keyspace,
      consistency: consistency,
      error: :public_key_not_found
    )
  end

  @doc """
  Updates the `realm_name` `jwt_public_key_pem` with the provided one.
  """
  def update_jwt_public_key_pem(realm_name, jwt_public_key_pem) do
    keyspace = Realm.keyspace_name(realm_name)

    consistency = Consistency.domain_model(:write)

    %{
      group: "auth",
      key: "jwt_public_key_pem",
      value: jwt_public_key_pem,
      value_type: :string
    }
    |> KvStore.insert(prefix: keyspace, consistency: consistency)
  end

  @doc """
  Retrieves the maximum datastream storage retention of a realm.
  Returns either `{:ok, limit}` or `{:error, reason}`.
  The limit is a strictly positive integer (if set), 0 if unset.
  """
  @spec get_datastream_maximum_storage_retention(String.t()) ::
          {:ok, non_neg_integer()} | {:error, atom()}
  def get_datastream_maximum_storage_retention(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    consistency = Consistency.domain_model(:read)

    opts = [
      prefix: keyspace,
      consistency: consistency,
      error: :fetch_error
    ]

    case KvStore.fetch_value(
           "realm_config",
           "datastream_maximum_storage_retention",
           :integer,
           opts
         ) do
      {:ok, value} ->
        {:ok, value}

      # not found means default maximum storage retention of 0
      {:error, :fetch_error} ->
        {:ok, 0}

      {:error, reason} ->
        Logger.warning(
          "Cannot get maximum datastream storage retention for realm #{realm_name}",
          tag: "get_datastream_maximum_storage_retention_fail"
        )

        {:error, reason}
    end
  end

  @doc """
  Retrieves the device registration limit of a realm.
  Returns either `{:ok, limit}` or `{:error, reason}`.
  The limit is an integer (if set) or `nil` (if unset).
  """
  @spec get_device_registration_limit(String.t()) ::
          {:ok, integer()} | {:ok, nil} | {:error, atom()}
  def get_device_registration_limit(realm_name) do
    keyspace = Realm.astarte_keyspace_name()

    consistency = Consistency.domain_model(:read)

    query =
      from realm in Realm,
        select: realm.device_registration_limit,
        where: [realm_name: ^realm_name]

    opts = [
      prefix: keyspace,
      consistency: consistency,
      error: :realm_not_found
    ]

    case Repo.fetch_one(query, opts) do
      {:ok, value} ->
        {:ok, value}

      {:error, reason} ->
        Logger.warning(
          "Cannot get device registration limit for realm #{realm_name}",
          tag: "get_device_registration_limit_fail"
        )

        {:error, reason}
    end
  end
end
