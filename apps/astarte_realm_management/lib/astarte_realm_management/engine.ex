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
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.RealmManagement.Engine do
  require Logger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.Core.Triggers.Trigger
  alias Astarte.RealmManagement.Queries
  alias CQEx.Client, as: DatabaseClient

  def install_interface(realm_name, interface_json, opts \\ []) do
    {connection_status, connection_result} = DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

    if String.contains?(String.downcase(interface_json), ["drop", "insert", "delete", "update", "keyspace", "table"]) do
      Logger.warn "Found possible CQL command in JSON interface: #{inspect interface_json}"
    end

    interface_result = Astarte.Core.InterfaceDocument.from_json(interface_json)

    cond do
      interface_result == :error ->
        Logger.warn "Received invalid interface JSON: #{inspect interface_json}"
        {:error, :invalid_interface_document}

      {connection_status, connection_result} == {:error, :shutdown} ->
        {:error, :realm_not_found}

      Astarte.RealmManagement.Queries.is_interface_major_available?(connection_result, elem(interface_result, 1).descriptor.name, elem(interface_result, 1).descriptor.major_version) == true ->
        {:error, :already_installed_interface}

      true ->
        {:ok, interface_document} = interface_result

        automaton_build_result = Astarte.Core.Mapping.EndpointsAutomaton.build(interface_document.mappings)

        cond do
          match?({:error, _}, automaton_build_result) ->
            automaton_build_result

          opts[:async] ->
            {:ok, automaton} = automaton_build_result
            Task.start_link(Astarte.RealmManagement.Queries, :install_new_interface, [connection_result, interface_document, automaton])
            {:ok, :started}

          true ->
            {:ok, automaton} = automaton_build_result
            Astarte.RealmManagement.Queries.install_new_interface(connection_result, interface_document, automaton)
        end
    end
  end

  def update_interface(realm_name, interface_json, opts \\ []) do
    {connection_status, connection_result} = DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

    if String.contains?(String.downcase(interface_json), ["drop", "insert", "delete", "update", "keyspace", "table"]) do
      Logger.warn "Found possible CQL command in JSON interface: #{inspect interface_json}"
    end

    interface_result = Astarte.Core.InterfaceDocument.from_json(interface_json)

    cond do
      interface_result == :error ->
        Logger.warn "Received invalid interface JSON: #{inspect interface_json}"
        {:error, :invalid_interface_document}

      {connection_status, connection_result} == {:error, :shutdown} ->
        {:error, :realm_not_found}

      Astarte.RealmManagement.Queries.is_interface_major_available?(connection_result, elem(interface_result, 1).descriptor.name, elem(interface_result, 1).descriptor.major_version) != true ->
        {:error, :interface_major_version_does_not_exist}

      true ->
        {:ok, interface_document} = interface_result

        if (opts[:async]) do
          Task.start_link(Astarte.RealmManagement.Queries, :update_interface, [connection_result, interface_document])
          {:ok, :started}
        else
          Astarte.RealmManagement.Queries.update_interface(connection_result, interface_document)
        end
    end
  end

  def delete_interface(realm_name, interface_name, interface_major_version, opts \\ []) do
    client = DatabaseClient.new!(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])

    cond do
      Astarte.RealmManagement.Queries.is_interface_major_available?(client, interface_name, interface_major_version) == false ->
        {:error, :interface_major_version_does_not_exist}

      true ->
        if (opts[:async]) do
          Task.start_link(Astarte.RealmManagement.Queries, :delete_interface, [client, interface_name, interface_major_version])
          {:ok, :started}
        else
          Astarte.RealmManagement.Queries.delete_interface(client, interface_name, interface_major_version)
        end
    end
  end

  def interface_source(realm_name, interface_name, interface_major_version) do
    case DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]) do
      {:error, :shutdown} ->
        {:error, :realm_not_found}

      {:ok, client} ->
        Astarte.RealmManagement.Queries.interface_source(client, interface_name, interface_major_version)
    end
  end

  def list_interface_versions(realm_name, interface_name) do
    case DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]) do
      {:error, :shutdown} ->
        {:error, :realm_not_found}

      {:ok, client} ->
        result = Astarte.RealmManagement.Queries.interface_available_versions(client, interface_name)

        if result != [] do
          {:ok, result}
        else
          {:error, :interface_not_found}
        end
    end
  end

  def get_interfaces_list(realm_name) do
    case DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]) do
      {:error, :shutdown} ->
        {:error, :realm_not_found}

      {:ok, client} ->
        result = Astarte.RealmManagement.Queries.get_interfaces_list(client)
        {:ok, result}
    end
  end

  def get_jwt_public_key_pem(realm_name) do
    with {:ok, client} <- DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]) do
      Astarte.RealmManagement.Queries.get_jwt_public_key_pem(client)
    else
      {:error, :shutdown} ->
        {:error, :realm_not_found}
    end
  end

  def update_jwt_public_key_pem(realm_name, jwt_public_key_pem) do
    with {:ok, client} <- DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name]) do
      Astarte.RealmManagement.Queries.update_jwt_public_key_pem(client, jwt_public_key_pem)
    else
      {:error, :shutdown} ->
        {:error, :realm_not_found}
    end
  end

  # InstallTrigger
  def install_trigger(realm_name, trigger_data, simple_trigger_data_containers) do
    with {:ok, client} <- get_database_client(realm_name) do

      trigger = Trigger.decode(trigger_data)

      simple_triggers =
        for simple_trigger_data_container <- simple_trigger_data_containers do
          %{
            object_id: simple_trigger_data_container.object_id,
            object_type: simple_trigger_data_container.object_type,
            simple_trigger_uuid: :uuid.get_v4(),
            simple_trigger: SimpleTriggerContainer.decode(simple_trigger_data_container.data)
          }
        end

      simple_trigger_uuids =
        for simple_trigger <- simple_triggers do
          simple_trigger[:simple_trigger_uuid]
        end

      trigger =
        %{ trigger |
          trigger_uuid: trigger.trigger_uuid || :uuid.get_v4(),
          simple_triggers_uuids: simple_trigger_uuids
        }

      # TODO: they should be batched together
      with :ok <- Queries.install_trigger(client, trigger) do
        target =
          %TriggerTargetContainer{
            trigger_target: {
              :amqp_trigger_target,
              %AMQPTriggerTarget{
                routing_key: "trigger_engine",
                parent_trigger_id: trigger.trigger_uuid
              }
            }
          }

        simple_trigger_install_success =
          Enum.all?(simple_triggers, fn simple_trigger ->
            Queries.install_simple_trigger(
              client,
              simple_trigger[:object_id],
              simple_trigger[:object_type],
              trigger.trigger_uuid,
              simple_trigger[:simple_trigger_uuid],
              simple_trigger[:simple_trigger],
              target
            ) == :ok
          end)

        if simple_trigger_install_success do
          :ok
        else
          {:error, :failed_simple_trigger_install}
        end
      end
    end
  end

  # GetTrigger
  def get_trigger(realm_name, trigger_name) do
    with {:ok, client} <- get_database_client(realm_name),
         {:ok, trigger} <- Queries.retrieve_trigger(client, trigger_name) do

      simple_triggers =
        for simple_trigger_uuid <- trigger.simple_triggers_uuids do
          Queries.retrieve_simple_trigger(client, trigger.trigger_uuid, simple_trigger_uuid)
        end

      everything_ok =
        Enum.all?(simple_triggers, fn simple_trigger ->
          match?({:ok, _}, simple_trigger)
        end)

        if everything_ok do
          simple_triggers_list =
            Enum.into(simple_triggers, [], fn item -> elem(item, 1) end)

          {
            :ok,
            %{
              trigger: trigger,
              simple_triggers: simple_triggers_list
            }
          }
      else
        {:error, :cannot_retrieve_simple_trigger}
      end
    end
  end

  # GetTriggersList
  def get_triggers_list(realm_name) do
    with {:ok, client} <- get_database_client(realm_name) do
      Queries.get_triggers_list(client)
    end
  end

  # DeleteTrigger
  def delete_trigger(realm_name, trigger_name) do
    with {:ok, client} <- get_database_client(realm_name) do
      Queries.delete_trigger(client, trigger_name)
      # TODO: delete also all child simple triggers
    end
  end

  defp get_database_client(realm_name) do
    DatabaseClient.new(List.first(Application.get_env(:cqerl, :cassandra_nodes)), [keyspace: realm_name])
  end

end
