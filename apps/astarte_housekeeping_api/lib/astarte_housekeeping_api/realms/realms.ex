#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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
  def create_realm(attrs \\ %{}) do
    changeset =
      %Realm{}
      |> Realm.changeset(attrs)

    with {:ok, %Realm{} = realm} <- Ecto.Changeset.apply_action(changeset, :insert) do
      case Housekeeping.create_realm(realm) do
        :ok -> {:ok, realm}
        {:ok, :started} -> {:ok, realm}
        {:error, reason} -> {:error, reason}
      end
    end
  end

  @doc """
  Updates a realm.

  ## Examples

      iex> update_realm(realm, %{field: new_value})
      {:ok, %Realm{}}

      iex> update_realm(realm, %{field: bad_value})
      {:error, ...}

  """
  def update_realm(%Realm{} = _realm, _attrs) do
    raise "TODO"
  end

  @doc """
  Deletes a Realm.

  ## Examples

      iex> delete_realm(realm_name)
      :ok

      iex> delete_realm(realm_name)
      {:error, ...}

  """
  def delete_realm(realm_name) do
    case Housekeeping.delete_realm(realm_name) do
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
