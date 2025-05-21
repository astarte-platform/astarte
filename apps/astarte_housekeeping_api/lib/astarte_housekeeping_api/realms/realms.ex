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

defmodule Astarte.Housekeeping.API.Realms do
  @moduledoc """
  The boundary for the Realms system.
  """

  alias Astarte.Housekeeping.API.Realms.Realm
  alias Astarte.Housekeeping.API.RPC.Housekeeping

  @doc """
  Returns the list of realms.

  ## Examples

      iex> list_realms()
      [%Realm{}, ...]

  """
  def list_realms do
    Housekeeping.list_realms()
  end

  @doc """
  Gets a single realm.

  ## Examples

      iex> get_realm!(123)
      %Realm{}

  """
  def get_realm(realm_name) do
    Housekeeping.get_realm(realm_name)
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
      case Housekeeping.create_realm(realm, opts) do
        :ok -> {:ok, realm}
        {:ok, :started} -> {:ok, realm}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Updates a realm with the provided list of attributes.
  Returns either {:ok, %Realm{}} or {:error, error}
  where `error` is an Ecto.Changeset describing the error.
  """
  @spec update_realm(binary(), map()) :: {:ok, Realm.t()} | {:error, Ecto.Changeset.t()}
  def update_realm(realm_name, attrs) do
    changeset = %Realm{realm_name: realm_name} |> Realm.update_changeset(attrs)

    with {:ok, %Realm{} = realm_update} <-
           Ecto.Changeset.apply_action(changeset, :update) do
      Housekeeping.update_realm(realm_update)
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
    case Housekeeping.delete_realm(realm_name, opts) do
      :ok -> :ok
      {:ok, :started} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Returns a datastructure for tracking realm changes.

  ## Examples

      iex> change_realm(realm)
      %Todo{...}

  """
  def change_realm(%Realm{} = _realm) do
    raise "TODO"
  end
end
