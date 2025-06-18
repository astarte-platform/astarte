#
# This file is part of Astarte.
#
# Copyright 2017 - 2025  SECO Mind Srl
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

defmodule Astarte.Housekeeping.API.Realms do
  @moduledoc """
  The boundary for the Realms system.
  """

  alias Astarte.Housekeeping.API.Realms.Core
  alias Astarte.Housekeeping.API.Realms.Queries
  alias Astarte.Housekeeping.API.Realms.Realm
  alias Ecto.Changeset

  require Logger

  @doc """
  Returns the list of realms.

  ## Examples

      iex> list_realms()
      [%Realm{}, ...]

  """
  def list_realms do
    Queries.list_realms()
  end

  @doc """
  Gets a single realm.

  ## Examples

      iex> get_realm!(123)
      %Realm{}

  """
  def get_realm(realm_name) do
    Queries.get_realm(realm_name)
  end

  @doc """
  Creates a realm.

  ## Examples

      iex> create_realm(%{field: value})
      {:ok, %Realm{}}

      iex> create_realm(%{field: bad_value})
      {:error, ...}

  """
  def create_realm(attrs \\ %{}, opts \\ []) do
    changeset =
      %Realm{}
      |> Realm.changeset(attrs)

    with {:ok, %Realm{} = realm} <-
           Ecto.Changeset.apply_action(changeset, :insert) do
      case Core.create_realm(realm, opts) do
        :ok -> {:ok, realm}
        {:ok, :started} -> {:ok, realm}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Updates a realm with the provided list of attributes.
  Returns either {:ok, %Realm{}} or {:error, error}
  """
  @spec update_realm(binary(), map()) :: {:ok, Realm.t()} | {:error, any()}
  def update_realm(realm_name, attrs) do
    changeset = %Realm{realm_name: realm_name} |> Realm.update_changeset(attrs)

    with {:ok, _realm} <- Changeset.apply_action(changeset, :update),
         {:ok, realm} <- Core.update_realm(realm_name, changeset.changes) do
      Logger.info("Successful update of realm #{realm_name}", tag: "realm_update_success")
      {:ok, realm}
    end
  end

  @doc """
  Deletes a Realm.

  ## Examples

      iex> delete_realm(realm_name)
      :ok

      iex> delete_realm(realm_name)
      {:error, ...}

  """
  def delete_realm(realm_name, opts \\ []) do
    Queries.delete_realm(realm_name, opts)
  end
end
