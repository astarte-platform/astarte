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
  alias Astarte.RealmManagement.API.RPC.AMQPClient

  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.RealmManagement.API.Triggers.Trigger
  alias Ecto.Changeset

  use Astarte.Core.Triggers.SimpleTriggersProtobuf

  require Logger

  @doc """
  Returns the list of triggers.
  """
  def list_triggers(realm_name) do
    with {:ok, triggers_list} <- AMQPClient.get_triggers_list(realm_name) do
      triggers_list
    end
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
  def get_trigger!(realm_name, trigger_name) do
    with {:ok, trigger} <- AMQPClient.get_trigger(realm_name, trigger_name) do
      %Trigger{
        name: trigger[:trigger].name,
        action: trigger[:trigger].action,
        simple_triggers: trigger[:simple_triggers]
      }
    end
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
    changeset =
      %Trigger{}
      |> Trigger.changeset(attrs)

    with {:ok, trigger_params} <- Changeset.apply_action(changeset, :insert),
         {:ok, encoded_action} <- Poison.encode(trigger_params.action),
         tagged_simple_triggers <-
           Enum.map(
             trigger_params.simple_triggers,
             &SimpleTriggerConfig.to_tagged_simple_trigger/1
           ),
         :ok <-
           AMQPClient.install_trigger(
             realm_name,
             trigger_params.name,
             encoded_action,
             tagged_simple_triggers
           ) do
      {:ok, %{trigger_params | id: trigger_params.name}}
    end
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
    with :ok <- AMQPClient.delete_trigger(realm_name, trigger.name) do
      {:ok, trigger}
    end
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
