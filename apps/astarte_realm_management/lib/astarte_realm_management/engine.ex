#
# This file is part of Astarte.
#
# Copyright 2017-2020 Ispirata Srl
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

defmodule Astarte.RealmManagement.Engine do
  require Logger
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Interface, as: InterfaceDocument
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.Core.Triggers.Trigger
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Interface
  alias Astarte.DataAccess.Mappings
  alias Astarte.RealmManagement.Engine
  alias Astarte.RealmManagement.Queries
  alias Astarte.RealmManagement.Config
  alias CQEx.Client, as: DatabaseClient

  def get_health() do
    _ = Logger.debug("Get health.")

    with {:ok, client} <- Database.connect(),
         :ok <- Queries.check_astarte_health(client, :quorum) do
      {:ok, %{status: :ready}}
    else
      {:error, :health_check_bad} ->
        with {:ok, client} <- Database.connect(),
             :ok <- Queries.check_astarte_health(client, :one) do
          {:ok, %{status: :degraded}}
        else
          {:error, :health_check_bad} ->
            {:ok, %{status: :bad}}

          {:error, :database_connection_error} ->
            {:ok, %{status: :error}}
        end

      {:error, :database_connection_error} ->
        {:ok, %{status: :error}}
    end
  end

  def install_interface(realm_name, interface_json, opts \\ []) do
    _ = Logger.info("Going to install a new interface.", tag: "install_interface")

    with {:ok, client} <- Database.connect(realm: realm_name),
         {:ok, json_obj} <- Jason.decode(interface_json),
         interface_changeset <- InterfaceDocument.changeset(%InterfaceDocument{}, json_obj),
         {:ok, interface_doc} <- Ecto.Changeset.apply_action(interface_changeset, :insert),
         interface_descriptor <- InterfaceDescriptor.from_interface(interface_doc),
         %InterfaceDescriptor{name: name, major_version: major} <- interface_descriptor,
         {:interface_avail, {:ok, false}} <-
           {:interface_avail, Queries.is_interface_major_available?(client, name, major)},
         :ok <- Queries.check_interface_name_collision(client, name),
         {:ok, automaton} <- EndpointsAutomaton.build(interface_doc.mappings) do
      _ =
        Logger.info("Installing interface.",
          interface: name,
          interface_major: major,
          tag: "install_interface_started"
        )

      if opts[:async] do
        # TODO: add _ = Logger.metadata(realm: realm_name)
        Task.start(Queries, :install_new_interface, [client, interface_doc, automaton])

        {:ok, :started}
      else
        Queries.install_new_interface(client, interface_doc, automaton)
      end
    else
      {:error, {:invalid, _invalid_str, _invalid_pos}} ->
        _ =
          Logger.warn("Received invalid interface JSON: #{inspect(interface_json)}.",
            tag: "invalid_json"
          )

        {:error, :invalid_interface_document}

      {:error, %Ecto.Changeset{} = changeset} ->
        _ =
          Logger.warn("Received invalid interface: #{inspect(changeset)}.",
            tag: "invalid_interface_document"
          )

        {:error, :invalid_interface_document}

      {:error, :database_connection_error} ->
        {:error, :realm_not_found}

      {:error, :database_error} ->
        {:error, :database_error}

      {:interface_avail, {:ok, true}} ->
        {:error, :already_installed_interface}

      {:error, :interface_name_collision} ->
        {:error, :interface_name_collision}

      {:error, :overlapping_mappings} ->
        {:error, :overlapping_mappings}
    end
  end

  def update_interface(realm_name, interface_json, opts \\ []) do
    _ = Logger.info("Going to perform interface update.", tag: "update_interface")

    with {:ok, client} <- Database.connect(realm: realm_name),
         {:ok, json_obj} <- Jason.decode(interface_json),
         interface_changeset <- InterfaceDocument.changeset(%InterfaceDocument{}, json_obj),
         {:ok, interface_doc} <- Ecto.Changeset.apply_action(interface_changeset, :insert),
         %InterfaceDocument{description: description, doc: doc} <- interface_doc,
         interface_descriptor <- InterfaceDescriptor.from_interface(interface_doc),
         %InterfaceDescriptor{name: name, major_version: major} <- interface_descriptor,
         {:interface_avail, {:ok, true}} <-
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
        # TODO: add _ = Logger.metadata(realm: realm_name)
        Task.start_link(__MODULE__, :execute_interface_update, [
          client,
          interface_update,
          new_mappings_list,
          automaton,
          description,
          doc
        ])

        {:ok, :started}
      else
        execute_interface_update(
          client,
          interface_update,
          new_mappings_list,
          automaton,
          description,
          doc
        )
      end
    else
      {:error, {:invalid, _invalid_str, _invalid_pos}} ->
        _ =
          Logger.warn("Received invalid interface JSON: #{inspect(interface_json)}.",
            tag: "invalid_json"
          )

        {:error, :invalid_interface_document}

      {:error, %Ecto.Changeset{} = changeset} ->
        _ =
          Logger.warn("Received invalid interface: #{inspect(changeset)}.",
            tag: "invalid_interface_document"
          )

        {:error, :invalid_interface_document}

      {:error, :database_connection_error} ->
        {:error, :realm_not_found}

      {:error, :database_error} ->
        {:error, :database_error}

      {:interface_avail, {:ok, false}} ->
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

  def execute_interface_update(client, interface_descriptor, new_mappings, automaton, descr, doc) do
    name = interface_descriptor.name
    major = interface_descriptor.major_version

    _ =
      Logger.info("Updating interface.",
        interface: name,
        interface_major: major,
        tag: "update_interface_started"
      )

    with :ok <- Queries.update_interface_storage(client, interface_descriptor, new_mappings) do
      Queries.update_interface(client, interface_descriptor, new_mappings, automaton, descr, doc)
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
      interface_id: interface_id
    } = installed_descriptor

    with %{
           name: ^name,
           major_version: ^major_version,
           type: ^type,
           ownership: ^ownership,
           aggregation: ^aggregation,
           interface_id: ^interface_id
         } <- new_descriptor do
      :ok
    else
      incompatible_value ->
        _ = Logger.debug("Incompatible change: #{inspect(incompatible_value)}.")
        {:error, :invalid_update}
    end
  end

  # TODO: Mappings documentation changes are discarded
  defp extract_new_mappings(db_client, %{mappings: upd_mappings} = interface_doc) do
    descriptor = InterfaceDescriptor.from_interface(interface_doc)

    with {:ok, mappings} <- Mappings.fetch_interface_mappings(db_client, descriptor.interface_id) do
      upd_mappings_map =
        Enum.into(upd_mappings, %{}, fn mapping ->
          {mapping.endpoint_id, mapping}
        end)

      maybe_new_mappings =
        Enum.reduce_while(mappings, upd_mappings_map, fn mapping, acc ->
          case drop_mapping_doc(Map.get(upd_mappings_map, mapping.endpoint_id)) do
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

  defp drop_mapping_doc(%Mapping{} = mapping) do
    %{mapping | description: nil, doc: nil}
  end

  defp drop_mapping_doc(nil) do
    nil
  end

  def delete_interface(realm_name, name, major, opts \\ []) do
    _ =
      Logger.info("Going to delete interface.",
        tag: "delete_interface",
        interface: name,
        interface_major: major
      )

    with {:major, 0} <- {:major, major},
         {:ok, client} <- Database.connect(realm: realm_name),
         {:major_is_avail, {:ok, true}} <-
           {:major_is_avail, Queries.is_interface_major_available?(client, name, 0)},
         {:devices, {:ok, false}} <-
           {:devices, Queries.is_any_device_using_interface?(client, name)},
         interface_id = CQLUtils.interface_id(name, major),
         {:triggers, {:ok, false}} <-
           {:triggers, Queries.has_interface_simple_triggers?(client, interface_id)} do
      if opts[:async] do
        # TODO: add _ = Logger.metadata(realm: realm_name)
        Task.start_link(Engine, :execute_interface_deletion, [client, name, major])

        {:ok, :started}
      else
        Engine.execute_interface_deletion(client, name, major)
      end
    else
      {:major, _} ->
        {:error, :forbidden}

      {:major_is_avail, {:ok, false}} ->
        {:error, :interface_major_version_does_not_exist}

      {:devices, {:ok, true}} ->
        {:error, :cannot_delete_currently_used_interface}

      {:triggers, {:ok, true}} ->
        {:error, :cannot_delete_currently_used_interface}

      {_, {:error, reason}} ->
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
      _ =
        Logger.info("Interface deletion started.",
          interface: name,
          interface_major: major,
          tag: "delete_interface_started"
        )

      Queries.delete_interface(client, name, major)
    end
  end

  def interface_source(realm_name, interface_name, major_version) do
    _ =
      Logger.debug("Get interface source.",
        interface: interface_name,
        interface_major: major_version
      )

    with {:ok, client} <- Database.connect(realm: realm_name),
         {:ok, interface} <- Queries.fetch_interface(client, interface_name, major_version) do
      Jason.encode(interface)
    end
  end

  def list_interface_versions(realm_name, interface_name) do
    _ = Logger.debug("List interface versions.", interface: interface_name)

    with {:ok, client} <- Database.connect(realm: realm_name) do
      Queries.interface_available_versions(client, interface_name)
    else
      {:error, :database_connection_error} ->
        {:error, :realm_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_interfaces_list(realm_name) do
    _ = Logger.debug("Get interfaces list.")

    with {:ok, client} <- Database.connect(realm: realm_name) do
      Queries.get_interfaces_list(client)
    else
      {:error, :database_connection_error} ->
        {:error, :realm_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_jwt_public_key_pem(realm_name) do
    _ = Logger.debug("Get JWT public key PEM.")

    with {:ok, client} <-
           DatabaseClient.new(
             List.first(Config.cqex_nodes!()),
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
             List.first(Config.cqex_nodes!()),
             keyspace: realm_name
           ) do
      _ = Logger.info("Updating JWT public key PEM.", tag: "updating_jwt_pub_key")
      Queries.update_jwt_public_key_pem(client, jwt_public_key_pem)
    else
      {:error, :shutdown} ->
        {:error, :realm_not_found}
    end
  end

  def install_trigger(realm_name, trigger_name, action, serialized_tagged_simple_triggers) do
    _ =
      Logger.info("Going to install a new trigger.",
        trigger_name: trigger_name,
        tag: "install_trigger"
      )

    with {:ok, client} <- get_database_client(realm_name),
         {:exists?, {:error, :trigger_not_found}} <-
           {:exists?, Queries.retrieve_trigger_uuid(client, trigger_name)},
         simple_trigger_maps = build_simple_trigger_maps(serialized_tagged_simple_triggers),
         trigger = build_trigger(trigger_name, simple_trigger_maps, action),
         %Trigger{trigger_uuid: trigger_uuid} = trigger,
         trigger_target = target_from_action(action, trigger_uuid),
         t_container = build_trigger_target_container(trigger_target),
         :ok <- validate_simple_triggers(client, simple_trigger_maps),
         # TODO: these should be batched together
         :ok <- install_simple_triggers(client, simple_trigger_maps, trigger_uuid, t_container) do
      _ =
        Logger.info("Installing trigger.",
          trigger_name: trigger_name,
          tag: "install_trigger_started"
        )

      Queries.install_trigger(client, trigger)
    else
      {:exists?, _} ->
        {:error, :already_installed_trigger}

      any ->
        any
    end
  end

  defp target_from_action(
         %{"amqp_exchange" => exchange, "amqp_routing_key" => key} = action,
         parent_uuid
       ) do
    %AMQPTriggerTarget{
      exchange: exchange,
      routing_key: key,
      parent_trigger_id: parent_uuid,
      static_headers: Map.get(action, "amqp_static_headers"),
      message_expiration_ms: Map.get(action, "amqp_message_expiration_ms"),
      message_priority: Map.get(action, "amqp_message_priority"),
      message_persistent: Map.get(action, "amqp_message_persistent")
    }
  end

  defp target_from_action(_action, parent_uuid) do
    %AMQPTriggerTarget{
      routing_key: "trigger_engine",
      parent_trigger_id: parent_uuid
    }
  end

  defp build_simple_trigger_maps(serialized_tagged_simple_triggers) do
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
  end

  defp build_trigger(trigger_name, simple_trigger_maps, action) do
    simple_trigger_uuids =
      for simple_trigger_map <- simple_trigger_maps do
        simple_trigger_map[:simple_trigger_uuid]
      end

    %Trigger{
      trigger_uuid: :uuid.get_v4(),
      simple_triggers_uuids: simple_trigger_uuids,
      action: action,
      name: trigger_name
    }
  end

  defp build_trigger_target_container(%AMQPTriggerTarget{} = trigger_target) do
    %TriggerTargetContainer{
      trigger_target: {
        :amqp_trigger_target,
        trigger_target
      }
    }
  end

  defp validate_simple_triggers(client, simple_trigger_maps) do
    Enum.reduce_while(simple_trigger_maps, :ok, fn
      %{simple_trigger: simple_trigger_container}, _acc ->
        %SimpleTriggerContainer{simple_trigger: {_tag, simple_trigger}} = simple_trigger_container

        case validate_simple_trigger(client, simple_trigger) do
          :ok ->
            {:cont, :ok}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
    end)
  end

  defp validate_simple_trigger(_client, %DataTrigger{interface_name: "*"}) do
    # TODO: we ignore catch-all interface triggers for now
    :ok
  end

  defp validate_simple_trigger(client, %DataTrigger{} = data_trigger) do
    %DataTrigger{
      interface_name: interface_name,
      interface_major: interface_major,
      value_match_operator: match_operator,
      match_path: match_path,
      data_trigger_type: data_trigger_type
    } = data_trigger

    # This will fail with {:error, :interface_not_found} if the interface does not exist
    with {:ok, interface} <- Queries.fetch_interface(client, interface_name, interface_major) do
      case interface.aggregation do
        :individual ->
          :ok

        :object ->
          if data_trigger_type != :INCOMING_DATA or match_operator != :ANY or match_path != "/*" do
            {:error, :invalid_object_aggregation_trigger}
          else
            :ok
          end
      end
    end
  end

  defp validate_simple_trigger(_client, _other_trigger) do
    # TODO: validate DeviceTrigger and IntrospectionTrigger
    :ok
  end

  defp install_simple_triggers(client, simple_trigger_maps, trigger_uuid, trigger_target) do
    Enum.reduce_while(simple_trigger_maps, :ok, fn
      simple_trigger_map, _acc ->
        %{
          object_id: object_id,
          object_type: object_type,
          simple_trigger_uuid: simple_trigger_uuid,
          simple_trigger: simple_trigger_container
        } = simple_trigger_map

        case Queries.install_simple_trigger(
               client,
               object_id,
               object_type,
               trigger_uuid,
               simple_trigger_uuid,
               simple_trigger_container,
               trigger_target
             ) do
          :ok ->
            {:cont, :ok}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
    end)
  end

  def get_trigger(realm_name, trigger_name) do
    _ = Logger.debug("Get trigger.", trigger_name: trigger_name)

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
    _ = Logger.debug("Get triggers list.")

    with {:ok, client} <- get_database_client(realm_name) do
      Queries.get_triggers_list(client)
    end
  end

  def delete_trigger(realm_name, trigger_name) do
    _ = Logger.info("Going to delete trigger.", trigger_name: trigger_name, tag: "delete_trigger")

    with {:ok, client} <- get_database_client(realm_name),
         {:ok, trigger} <- Queries.retrieve_trigger(client, trigger_name) do
      _ =
        Logger.info("Deleting trigger.", trigger_name: trigger_name, tag: "delete_trigger_started")

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
      List.first(Config.cqex_nodes!()),
      keyspace: realm_name
    )
  end
end
