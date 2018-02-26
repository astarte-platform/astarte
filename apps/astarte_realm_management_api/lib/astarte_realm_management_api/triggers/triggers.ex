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

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.Utils, as: SimpleTriggersUtils
  alias Astarte.RealmManagement.API.Triggers.Trigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger
  alias Ecto.Changeset

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

    with {:ok, options} <- Changeset.apply_action(changeset, :insert) do
      trigger =
        %Astarte.Core.Triggers.Trigger{
          name: options.name,
          action: options.action
        }

      simple_triggers =
        for item <- options.simple_triggers do
          %{
            # 2 is interface object type
            object_type: 2,
            object_id: CQLUtils.interface_id(item["interface_name"], item["interface_major"]),
            simple_trigger: decode_simple_trigger(item["simple_trigger"])
          }
        end

      with :ok <- AMQPClient.install_trigger(realm_name, trigger, simple_triggers) do
        {:ok, %Trigger{id: options.name}}
      end
    end
  end

  def decode_simple_trigger(%{"type" => "DataTrigger"} = simple_trigger) do
    data_trigger_type =
      case simple_trigger["on"] do
        "INCOMING_DATA" ->
          :INCOMING_DATA

        "VALUE_CHANGE" ->
          :VALUE_CHANGE

        "VALUE_CHANGE_APPLIED" ->
          :VALUE_CHANGE_APPLIED

        "PATH_CREATED" ->
          :PATH_CREATED

        "PATH_REMOVED" ->
          :PATH_REMOVED

        "VALUE_STORED" ->
          :VALUE_STORED
      end

    operator_type =
      case simple_trigger["value_match_operator"] do
        "GREATER_THAN" ->
          :GREATER_THAN
      end

    %SimpleTriggerContainer{
      simple_trigger: {
        :data_trigger,
        %DataTrigger{
          known_value: Bson.encode(%{v: simple_trigger["known_value"]}),
          match_path: simple_trigger["match_path"],
          data_trigger_type: data_trigger_type,
          value_match_operator: operator_type
        }
      }
    }
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
