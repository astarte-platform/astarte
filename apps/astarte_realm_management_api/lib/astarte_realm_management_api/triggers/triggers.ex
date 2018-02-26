#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
#

defmodule Astarte.RealmManagement.API.Triggers do
  @moduledoc """
  The Triggers context.
  """

  import Ecto.Query, warn: false
  alias Astarte.RealmManagement.API.Repo

  alias Astarte.RealmManagement.API.Triggers.Trigger

  require Logger

  @doc """
  Returns the list of triggers.

  ## Examples

      iex> list_triggers()
      [%Trigger{}, ...]

  """
  def list_triggers(realm_name) do
    ["mock_trigger_1", "mock_trigger_2", "mock_trigger_3"]
  end

  @doc """
  Gets a single trigger.

  Raises `Ecto.NoResultsError` if the Trigger does not exist.

  ## Examples

      iex> get_trigger!(123)
      %Trigger{}

      iex> get_trigger!(456)
      ** (Ecto.NoResultsError)

  """
  def get_trigger!(realm_name, id) do
    %Trigger{
      id: id
    }
  end

  @doc """
  Creates a trigger.

  ## Examples

      iex> create_trigger(%{field: value})
      {:ok, %Trigger{}}

      iex> create_trigger(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_trigger(realm_name, attrs \\ %{}) do
    Logger.debug("Create: #{inspect(attrs)}")
    %Trigger{}
    |> Trigger.changeset(attrs)

    {:ok, %Trigger{id: "mock_trigger_4"}}
  end

  @doc """
  Updates a trigger.

  ## Examples

      iex> update_trigger(trigger, %{field: new_value})
      {:ok, %Trigger{}}

      iex> update_trigger(trigger, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_trigger(realm_name, %Trigger{} = trigger, attrs) do
    Logger.debug("Update: #{inspect(trigger)}")
    trigger
    |> Trigger.changeset(attrs)

    {:ok, %Trigger{id: "mock_trigger_4"}}
  end

  @doc """
  Deletes a Trigger.

  ## Examples

      iex> delete_trigger(trigger)
      {:ok, %Trigger{}}

      iex> delete_trigger(trigger)
      {:error, %Ecto.Changeset{}}

  """
  def delete_trigger(realm_name, %Trigger{} = trigger) do
    Logger.debug("Delete: #{inspect(trigger)}")
    {:ok, %Trigger{id: "mock_trigger_4"}}
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking trigger changes.

  ## Examples

      iex> change_trigger(trigger)
      %Ecto.Changeset{source: %Trigger{}}

  """
  def change_trigger(realm_name, %Trigger{} = trigger) do
    Trigger.changeset(trigger, %{})
  end
end
