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
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.InterfaceDocument
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.Core.Triggers.Trigger
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Interface
  alias Astarte.DataAccess.Mappings
  alias Astarte.RealmManagement.Engine
  alias Astarte.RealmManagement.Queries
  alias CQEx.Client, as: DatabaseClient

  def install_interface(realm_name, interface_json, opts \\ []) do
    {connection_status, connection_result} =
      DatabaseClient.new(
        List.first(Application.get_env(:cqerl, :cassandra_nodes)),
        keyspace: realm_name
      )

    if String.contains?(String.downcase(interface_json), [
         "drop",
         "insert",
         "delete",
         "update",
         "keyspace",
         "table"
       ]) do
      Logger.warn("Found possible CQL command in JSON interface: #{inspect(interface_json)}")
    end

    interface_result = InterfaceDocument.from_json(interface_json)

    cond do
      interface_result == :error ->
        Logger.warn("Received invalid interface JSON: #{inspect(interface_json)}")
        {:error, :invalid_interface_document}

      {connection_status, connection_result} == {:error, :shutdown} ->
        {:error, :realm_not_found}

      Queries.is_interface_major_available?(
        connection_result,
        elem(interface_result, 1).descriptor.name,
        elem(interface_result, 1).descriptor.major_version
      ) == true ->
        {:error, :already_installed_interface}

      true ->
        {:ok, interface_document} = interface_result

        automaton_build_result = EndpointsAutomaton.build(interface_document.mappings)

        cond do
          match?({:error, _}, automaton_build_result) ->
            automaton_build_result

          opts[:async] ->
            {:ok, automaton} = automaton_build_result

            Task.start_link(Queries, :install_new_interface, [
              connection_result,
              interface_document,
              automaton
            ])

            {:ok, :started}

          true ->
            {:ok, automaton} = automaton_build_result
            Queries.install_new_interface(connection_result, interface_document, automaton)
        end
    end
  end

  def update_interface(realm_name, interface_json, opts \\ []) do
    with {:ok, client} <- Database.connect(realm_name),
         {:interface, {:ok, interface_doc}} <-
           {:interface, InterfaceDocument.from_json(interface_json)},
         %InterfaceDocument{descriptor: interface_descriptor, source: source} <- interface_doc,
         %InterfaceDescriptor{name: name, major_version: major} <- interface_descriptor,
         {:interface_avail, true} <-
           {:interface_avail, Queries.is_interface_major_available?(client, name, major)},
         {:ok, installed_interface} <- Interface.fetch_interface_descriptor(client, name, major),
         :ok <- error_on_incompatible_descriptor(installed_interface, interface_descriptor),
         :ok <- error_on_downgrade(installed_interface, interface_descriptor),
         {:ok, new_mappings} <- extract_new_mappings(client, interface_doc),
         {:ok, automaton} <- EndpointsAutomaton.build(interface_doc.mappings) do
      new_mappings_list = Map.values(new_mappings)

      interface_update =
        Map.merge(installed_interface, interface_descriptor, fn _k, old, new ->
          new || old
        end)

      if opts[:async] do
        Task.start_link(__MODULE__, :execute_interface_update, [
          client,
          interface_update,
          new_mappings_list,
          automaton,
          source
        ])

        {:ok, :started}
      else
        execute_interface_update(
          client,
          interface_update,
          new_mappings_list,
          automaton,
          source
        )
      end
    else
      {:error, :database_connection_error} ->
        {:error, :realm_not_found}

      {:error, :database_error} ->
        {:error, :database_error}

      {:interface, :error} ->
        Logger.warn("Received invalid interface JSON: #{inspect(interface_json)}")
        {:error, :invalid_interface_document}

      {:interface_avail, false} ->
        {:error, :interface_major_version_does_not_exist}

      {:error, :same_version} ->
        {:error, :minor_version_not_increased}

      {:error, :invalid_update} ->
        {:error, :invalid_update}

      {:error, :downgrade_not_allowed} ->
        {:error, :downgrade_not_allowed}

      {:error, :missing_endpoints} ->
        {:error, :missing_endpoints}

      {:error, :incompatible_endpoint_change} ->
        {:error, :incompatible_endpoint_change}

      {:error, :overlapping_mappings} ->
        {:error, :overlapping_mappings}
    end
  end

  def execute_interface_update(client, interface_descriptor, new_mappings, automaton, source) do
    with :ok <- Queries.update_interface_storage(client, interface_descriptor, new_mappings) do
      Queries.update_interface(client, interface_descriptor, new_mappings, automaton, source)
    end
  end

  defp error_on_downgrade(
         %InterfaceDescriptor{minor_version: installed_minor},
         %InterfaceDescriptor{minor_version: minor}
       ) do
    cond do
      installed_minor < minor ->
        :ok

      installed_minor == minor ->
        {:error, :same_version}

      installed_minor > minor ->
        {:error, :downgrade_not_allowed}
    end
  end

  defp error_on_incompatible_descriptor(installed_descriptor, new_descriptor) do
    %{
      name: name,
      major_version: major_version,
      type: type,
      ownership: ownership,
      aggregation: aggregation,
      explicit_timestamp: explicit_timestamp,
      has_metadata: has_metadata,
      interface_id: interface_id
    } = installed_descriptor

    with %{
           name: ^name,
           major_version: ^major_version,
           type: ^type,
           ownership: ^ownership,
           aggregation: ^aggregation,
           explicit_timestamp: ^explicit_timestamp,
           has_metadata: ^has_metadata,
           interface_id: ^interface_id
         } <- new_descriptor do
      :ok
    else
      incompatible_value ->
        Logger.debug("Incompatible change: #{inspect(incompatible_value)}")
        {:error, :invalid_update}
    end
  end

  defp extract_new_mappings(db_client, %{descriptor: descriptor, mappings: upd_mappings}) do
    with {:ok, mappings} <- Mappings.fetch_interface_mappings(db_client, descriptor.interface_id) do
      upd_mappings_map =
        Enum.into(upd_mappings, %{}, fn mapping ->
          {mapping.endpoint_id, mapping}
        end)

      maybe_new_mappings =
        Enum.reduce_while(mappings, upd_mappings_map, fn mapping, acc ->
          case Map.get(upd_mappings_map, mapping.endpoint_id) do
            nil ->
              {:halt, {:error, :missing_endpoints}}

            ^mapping ->
              {:cont, Map.delete(acc, mapping.endpoint_id)}

            _ ->
              {:halt, {:error, :incompatible_endpoint_change}}
          end
        end)

      if is_map(maybe_new_mappings) do
        {:ok, maybe_new_mappings}
      else
        maybe_new_mappings
      end
    end
  end

  def delete_interface(realm_name, name, major, opts \\ []) do
    with {:major, 0} <- {:major, major},
         {:ok, client} <- Database.connect(realm_name),
         {:major_is_avail, true} <-
           {:major_is_avail, Queries.is_interface_major_available?(client, name, 0)},
         {:devices, {:ok, false}} <-
           {:devices, Queries.is_any_device_using_interface?(client, name)} do
      if opts[:async] do
        Task.start_link(Engine, :execute_interface_deletion, [client, name, major])

        {:ok, :started}
      else
        Engine.execute_interface_deletion(client, name, major)
      end
    else
      {:major, _} ->
        {:error, :forbidden}

      {:major_is_avail, false} ->
        {:error, :interface_major_version_does_not_exist}

      {:devices, {:ok, true}} ->
        {:error, :cannot_delete_currently_used_interface}

      {:devices, {:error, reason}} ->
        {:error, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def execute_interface_deletion(client, name, major) do
    with {:ok, interface_row} <- Interface.retrieve_interface_row(client, name, major),
         {:ok, descriptor} <- InterfaceDescriptor.from_db_result(interface_row),
         :ok <- Queries.delete_interface_storage(client, descriptor),
         :ok <- Queries.delete_devices_with_data_on_interface(client, name) do
      Queries.delete_interface(client, name, major)
    end
  end

  def interface_source(realm_name, interface_name, interface_major_version) do
    case DatabaseClient.new(
           List.first(Application.get_env(:cqerl, :cassandra_nodes)),
           keyspace: realm_name
         ) do
      {:error, :shutdown} ->
        {:error, :realm_not_found}

      {:ok, client} ->
        Queries.interface_source(client, interface_name, interface_major_version)
    end
  end

  def list_interface_versions(realm_name, interface_name) do
    case DatabaseClient.new(
           List.first(Application.get_env(:cqerl, :cassandra_nodes)),
           keyspace: realm_name
         ) do
      {:error, :shutdown} ->
        {:error, :realm_not_found}

      {:ok, client} ->
        result = Queries.interface_available_versions(client, interface_name)

        if result != [] do
          {:ok, result}
        else
          {:error, :interface_not_found}
        end
    end
  end

  def get_interfaces_list(realm_name) do
    case DatabaseClient.new(
           List.first(Application.get_env(:cqerl, :cassandra_nodes)),
           keyspace: realm_name
         ) do
      {:error, :shutdown} ->
        {:error, :realm_not_found}

      {:ok, client} ->
        result = Queries.get_interfaces_list(client)
        {:ok, result}
    end
  end

  def get_jwt_public_key_pem(realm_name) do
    with {:ok, client} <-
           DatabaseClient.new(
             List.first(Application.get_env(:cqerl, :cassandra_nodes)),
             keyspace: realm_name
           ) do
      Queries.get_jwt_public_key_pem(client)
    else
      {:error, :shutdown} ->
        {:error, :realm_not_found}
    end
  end

  def update_jwt_public_key_pem(realm_name, jwt_public_key_pem) do
    with {:ok, client} <-
           DatabaseClient.new(
             List.first(Application.get_env(:cqerl, :cassandra_nodes)),
             keyspace: realm_name
           ) do
      Queries.update_jwt_public_key_pem(client, jwt_public_key_pem)
    else
      {:error, :shutdown} ->
        {:error, :realm_not_found}
    end
  end

  def install_trigger(realm_name, trigger_name, action, serialized_tagged_simple_triggers) do
    with {:ok, client} <- get_database_client(realm_name) do
      simple_triggers =
        for serialized_tagged_simple_trigger <- serialized_tagged_simple_triggers do
          %TaggedSimpleTrigger{
            object_id: object_id,
            object_type: object_type,
            simple_trigger_container: simple_trigger_container
          } = TaggedSimpleTrigger.decode(serialized_tagged_simple_trigger)

          %{
            object_id: object_id,
            object_type: object_type,
            simple_trigger_uuid: :uuid.get_v4(),
            simple_trigger: simple_trigger_container
          }
        end

      simple_trigger_uuids =
        for simple_trigger <- simple_triggers do
          simple_trigger[:simple_trigger_uuid]
        end

      trigger = %Trigger{
        trigger_uuid: :uuid.get_v4(),
        simple_triggers_uuids: simple_trigger_uuids,
        action: action,
        name: trigger_name
      }

      # TODO: they should be batched together
      with :ok <- Queries.install_trigger(client, trigger) do
        target = %TriggerTargetContainer{
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

  def get_trigger(realm_name, trigger_name) do
    with {:ok, client} <- get_database_client(realm_name),
         {:ok, %Trigger{} = trigger} <- Queries.retrieve_trigger(client, trigger_name) do
      %Trigger{
        trigger_uuid: parent_uuid,
        simple_triggers_uuids: simple_triggers_uuids
      } = trigger

      # TODO: use batch
      {everything_ok?, serialized_tagged_simple_triggers} =
        Enum.reduce(simple_triggers_uuids, {true, []}, fn
          _uuid, {false, _triggers_acc} ->
            # Avoid DB calls if we're not ok
            {false, []}

          uuid, {true, acc} ->
            case Queries.retrieve_tagged_simple_trigger(client, parent_uuid, uuid) do
              {:ok, %TaggedSimpleTrigger{} = result} ->
                {true, [TaggedSimpleTrigger.encode(result) | acc]}

              {:error, _reason} ->
                {false, []}
            end
        end)

      if everything_ok? do
        {
          :ok,
          %{
            trigger: trigger,
            serialized_tagged_simple_triggers: serialized_tagged_simple_triggers
          }
        }
      else
        {:error, :cannot_retrieve_simple_trigger}
      end
    end
  end

  def get_triggers_list(realm_name) do
    with {:ok, client} <- get_database_client(realm_name) do
      Queries.get_triggers_list(client)
    end
  end

  def delete_trigger(realm_name, trigger_name) do
    with {:ok, client} <- get_database_client(realm_name),
         {:ok, trigger} <- Queries.retrieve_trigger(client, trigger_name) do
      delete_all_succeeded =
        Enum.all?(trigger.simple_triggers_uuids, fn simple_trigger_uuid ->
          Queries.delete_simple_trigger(client, trigger.trigger_uuid, simple_trigger_uuid) == :ok
        end)

      if delete_all_succeeded do
        Queries.delete_trigger(client, trigger_name)
      else
        {:error, :cannot_delete_simple_trigger}
      end
    end
  end

  defp get_database_client(realm_name) do
    DatabaseClient.new(
      List.first(Application.get_env(:cqerl, :cassandra_nodes)),
      keyspace: realm_name
    )
  end
end
