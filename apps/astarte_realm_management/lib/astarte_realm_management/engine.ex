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
  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.PolicyProtobuf.Policy, as: PolicyProto
  alias Astarte.DataAccess.Interface
  alias Astarte.DataAccess.Mappings
  alias Astarte.RealmManagement.Engine
  alias Astarte.RealmManagement.Engine.MappingUpdates
  alias Astarte.RealmManagement.Queries

  def get_health() do
    _ = Logger.debug("Get health.")

    with :ok <- Queries.check_astarte_health(:quorum) do
      {:ok, %{status: :ready}}
    else
      {:error, :health_check_bad} ->
        with :ok <- Queries.check_astarte_health(:one) do
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

    with {:ok, json_obj} <- Jason.decode(interface_json),
         interface_changeset <- InterfaceDocument.changeset(%InterfaceDocument{}, json_obj),
         {:ok, interface_doc} <- Ecto.Changeset.apply_action(interface_changeset, :insert),
         interface_descriptor <- InterfaceDescriptor.from_interface(interface_doc),
         %InterfaceDescriptor{name: name, major_version: major} <- interface_descriptor,
         {:interface_avail, {:ok, false}} <-
           {:interface_avail, Queries.is_interface_major_available?(realm_name, name, major)},
         :ok <- Queries.check_interface_name_collision(realm_name, name),
         {:ok, automaton} <- EndpointsAutomaton.build(interface_doc.mappings) do
      _ =
        Logger.info("Installing interface.",
          interface: name,
          interface_major: major,
          tag: "install_interface_started"
        )

      if opts[:async] do
        # TODO: add _ = Logger.metadata(realm: realm_name)
        Task.start(Queries, :install_new_interface, [realm_name, interface_doc, automaton])

        {:ok, :started}
      else
        Queries.install_new_interface(realm_name, interface_doc, automaton)
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

    with {:ok, json_obj} <- Jason.decode(interface_json),
         interface_changeset <- InterfaceDocument.changeset(%InterfaceDocument{}, json_obj),
         {:ok, interface_doc} <- Ecto.Changeset.apply_action(interface_changeset, :insert),
         %InterfaceDocument{description: description, doc: doc} <- interface_doc,
         interface_descriptor <- InterfaceDescriptor.from_interface(interface_doc),
         %InterfaceDescriptor{name: name, major_version: major} <- interface_descriptor,
         {:interface_avail, {:ok, true}} <-
           {:interface_avail, Queries.is_interface_major_available?(realm_name, name, major)},
         {:ok, installed_interface} <-
           Interface.fetch_interface_descriptor(realm_name, name, major),
         :ok <- error_on_incompatible_descriptor(installed_interface, interface_descriptor),
         :ok <- error_on_downgrade(installed_interface, interface_descriptor),
         {:ok, mapping_updates} <- extract_mapping_updates(realm_name, interface_doc),
         {:ok, automaton} <- EndpointsAutomaton.build(interface_doc.mappings) do
      interface_update =
        Map.merge(installed_interface, interface_descriptor, fn _k, old, new ->
          new || old
        end)

      if opts[:async] do
        # TODO: add _ = Logger.metadata(realm: realm_name)
        Task.start_link(__MODULE__, :execute_interface_update, [
          realm_name,
          interface_update,
          mapping_updates,
          automaton,
          description,
          doc
        ])

        {:ok, :started}
      else
        execute_interface_update(
          realm_name,
          interface_update,
          mapping_updates,
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

  def execute_interface_update(
        realm_name,
        interface_descriptor,
        %MappingUpdates{} = mapping_updates,
        automaton,
        descr,
        doc
      ) do
    name = interface_descriptor.name
    major = interface_descriptor.major_version

    _ =
      Logger.info("Updating interface.",
        interface: name,
        interface_major: major,
        tag: "update_interface_started"
      )

    %MappingUpdates{new: new_mappings, updated: updated_mappings} = mapping_updates
    all_changed_mappings = new_mappings ++ updated_mappings

    with :ok <- Queries.update_interface_storage(realm_name, interface_descriptor, new_mappings) do
      Queries.update_interface(
        realm_name,
        interface_descriptor,
        all_changed_mappings,
        automaton,
        descr,
        doc
      )
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

  defp extract_mapping_updates(realm_name, %{mappings: upd_mappings} = interface_doc) do
    descriptor = InterfaceDescriptor.from_interface(interface_doc)

    with {:ok, mappings_map} <-
           Mappings.fetch_interface_mappings_map(realm_name, descriptor.interface_id,
             include_docs: true
           ) do
      upd_mappings_map =
        Enum.into(upd_mappings, %{}, fn mapping ->
          {mapping.endpoint_id, mapping}
        end)

      existing_endpoints = Map.keys(mappings_map)
      {existing_mappings, new_mappings} = Map.split(upd_mappings_map, existing_endpoints)

      with {:ok, changed_mappings} <- extract_changed_mappings(mappings_map, existing_mappings) do
        mapping_updates = %MappingUpdates{
          new: Map.values(new_mappings),
          updated: Map.values(changed_mappings)
        }

        {:ok, mapping_updates}
      end
    end
  end

  defp extract_changed_mappings(old_mappings, existing_mappings) do
    Enum.reduce_while(old_mappings, {:ok, %{}}, fn {mapping_id, old_mapping}, {:ok, acc} ->
      with {:ok, updated_mapping} <- Map.fetch(existing_mappings, mapping_id),
           {:allowed, true} <- {:allowed, allowed_mapping_update?(old_mapping, updated_mapping)},
           {:updated, true} <- {:updated, is_mapping_updated?(old_mapping, updated_mapping)} do
        {:cont, {:ok, Map.put(acc, mapping_id, updated_mapping)}}
      else
        :error ->
          {:halt, {:error, :missing_endpoints}}

        {:allowed, false} ->
          {:halt, {:error, :incompatible_endpoint_change}}

        {:updated, false} ->
          {:cont, {:ok, acc}}
      end
    end)
  end

  defp allowed_mapping_update?(mapping, upd_mapping) do
    new_mapping = drop_mapping_negligible_fields(upd_mapping)
    old_mapping = drop_mapping_negligible_fields(mapping)

    new_mapping == old_mapping
  end

  defp is_mapping_updated?(mapping, upd_mapping) do
    mapping.explicit_timestamp != upd_mapping.explicit_timestamp or
      mapping.doc != upd_mapping.doc or
      mapping.description != upd_mapping.description or
      mapping.retention != upd_mapping.retention or
      mapping.expiry != upd_mapping.expiry
  end

  defp drop_mapping_negligible_fields(%Mapping{} = mapping) do
    %{
      mapping
      | doc: nil,
        description: nil,
        explicit_timestamp: false,
        retention: nil,
        expiry: nil
    }
  end

  def delete_interface(realm_name, name, major, opts \\ []) do
    _ =
      Logger.info("Going to delete interface.",
        tag: "delete_interface",
        interface: name,
        interface_major: major
      )

    with {:major, 0} <- {:major, major},
         {:major_is_avail, {:ok, true}} <-
           {:major_is_avail, Queries.is_interface_major_available?(realm_name, name, 0)},
         {:devices, {:ok, false}} <-
           {:devices, Queries.is_any_device_using_interface?(realm_name, name)},
         interface_id = CQLUtils.interface_id(name, major),
         {:triggers, {:ok, false}} <-
           {:triggers, Queries.has_interface_simple_triggers?(realm_name, interface_id)} do
      if opts[:async] do
        # TODO: add _ = Logger.metadata(realm: realm_name)
        Task.start_link(Engine, :execute_interface_deletion, [realm_name, name, major])

        {:ok, :started}
      else
        Engine.execute_interface_deletion(realm_name, name, major)
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

  def execute_interface_deletion(realm_name, name, major) do
    with {:ok, interface_row} <- Interface.retrieve_interface_row(realm_name, name, major),
         {:ok, descriptor} <- InterfaceDescriptor.from_db_result(interface_row),
         :ok <- Queries.delete_interface_storage(realm_name, descriptor),
         :ok <- Queries.delete_devices_with_data_on_interface(realm_name, name) do
      _ =
        Logger.info("Interface deletion started.",
          interface: name,
          interface_major: major,
          tag: "delete_interface_started"
        )

      Queries.delete_interface(realm_name, name, major)
    end
  end

  def interface_source(realm_name, interface_name, major_version) do
    _ =
      Logger.debug("Get interface source.",
        interface: interface_name,
        interface_major: major_version
      )

    with {:ok, interface} <-
           Queries.fetch_interface(realm_name, interface_name, major_version, include_docs: true) do
      Jason.encode(interface)
    end
  end

  def list_interface_versions(realm_name, interface_name) do
    _ = Logger.debug("List interface versions.", interface: interface_name)

    with {:ok, versions} <- Queries.interface_available_versions(realm_name, interface_name) do
      {:ok, versions}
    else
      {:error, :database_connection_error} ->
        {:error, :realm_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_interfaces_list(realm_name) do
    _ = Logger.debug("Get interfaces list.")

    with {:ok, list} <- Queries.get_interfaces_list(realm_name) do
      {:ok, list}
    else
      {:error, :database_connection_error} ->
        {:error, :realm_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def get_jwt_public_key_pem(realm_name) do
    _ = Logger.debug("Get JWT public key PEM.")

    case Queries.get_jwt_public_key_pem(realm_name) do
      {:ok, result} -> {:ok, result}
      {:error, :public_key_not_found} -> {:error, :realm_not_found}
    end
  end

  def update_jwt_public_key_pem(realm_name, jwt_public_key_pem) do
    _ = Logger.info("Updating JWT public key PEM.", tag: "updating_jwt_pub_key")
    Queries.update_jwt_public_key_pem(realm_name, jwt_public_key_pem)
  end

  def install_trigger(
        realm_name,
        trigger_name,
        trigger_policy_name,
        action,
        serialized_tagged_simple_triggers
      ) do
    _ =
      Logger.info("Going to install a new trigger.",
        trigger_name: trigger_name,
        tag: "install_trigger"
      )

    with {:exists?, {:error, :trigger_not_found}} <-
           {:exists?, Queries.retrieve_trigger_uuid(realm_name, trigger_name)},
         simple_trigger_maps = build_simple_trigger_maps(serialized_tagged_simple_triggers),
         trigger = build_trigger(trigger_name, trigger_policy_name, simple_trigger_maps, action),
         %Trigger{trigger_uuid: trigger_uuid} = trigger,
         {:ok, action_map} <- Jason.decode(action),
         trigger_target = target_from_action(action_map, trigger_uuid),
         t_container = build_trigger_target_container(trigger_target),
         :ok <- validate_simple_triggers(realm_name, simple_trigger_maps),
         # TODO: these should be batched together
         :ok <-
           install_simple_triggers(realm_name, simple_trigger_maps, trigger_uuid, t_container),
         :ok <- install_trigger_policy_link(realm_name, trigger_uuid, trigger_policy_name) do
      _ =
        Logger.info("Installing trigger.",
          trigger_name: trigger_name,
          tag: "install_trigger_started"
        )

      Queries.install_trigger(realm_name, trigger)
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
    static_headers =
      Map.get(action, "amqp_static_headers", %{})
      |> Enum.to_list()

    %AMQPTriggerTarget{
      exchange: exchange,
      routing_key: key,
      parent_trigger_id: parent_uuid,
      static_headers: static_headers,
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

  defp build_trigger(trigger_name, policy, simple_trigger_maps, action) do
    simple_trigger_uuids =
      for simple_trigger_map <- simple_trigger_maps do
        simple_trigger_map[:simple_trigger_uuid]
      end

    policy =
      if policy == "" do
        nil
      else
        policy
      end

    %Trigger{
      trigger_uuid: :uuid.get_v4(),
      simple_triggers_uuids: simple_trigger_uuids,
      action: action,
      name: trigger_name,
      policy: policy
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

  defp validate_simple_triggers(realm_name, simple_trigger_maps) do
    Enum.reduce_while(simple_trigger_maps, :ok, fn
      %{simple_trigger: simple_trigger_container}, _acc ->
        %SimpleTriggerContainer{simple_trigger: {_tag, simple_trigger}} = simple_trigger_container

        case validate_simple_trigger(realm_name, simple_trigger) do
          :ok ->
            {:cont, :ok}

          {:error, reason} ->
            {:halt, {:error, reason}}
        end
    end)
  end

  defp validate_simple_trigger(_realm_name, %DataTrigger{interface_name: "*"}) do
    # TODO: we ignore catch-all interface triggers for now
    :ok
  end

  defp validate_simple_trigger(realm_name, %DataTrigger{} = data_trigger) do
    %DataTrigger{
      interface_name: interface_name,
      interface_major: interface_major,
      value_match_operator: match_operator,
      match_path: match_path,
      data_trigger_type: data_trigger_type
    } = data_trigger

    # This will fail with {:error, :interface_not_found} if the interface does not exist
    with {:ok, interface} <- Queries.fetch_interface(realm_name, interface_name, interface_major) do
      case interface.aggregation do
        :individual ->
          cond do
            interface.type != :properties and properties_trigger_type?(data_trigger_type) ->
              {:error, :invalid_datastream_trigger}

            match_path == "/*" and
                (data_trigger_type == :VALUE_CHANGE or data_trigger_type == :VALUE_CHANGE_APPLIED) ->
              # TODO: this is a workaround to a data updater plant limitation
              # see also https://github.com/astarte-platform/astarte/issues/513
              {:error, :unsupported_trigger_type}

            true ->
              :ok
          end

        :object ->
          if data_trigger_type != :INCOMING_DATA or match_operator != :ANY or match_path != "/*" do
            {:error, :invalid_object_aggregation_trigger}
          else
            :ok
          end
      end
    end
  end

  defp validate_simple_trigger(_realm_name, _other_trigger) do
    # TODO: validate DeviceTrigger and IntrospectionTrigger
    :ok
  end

  defp properties_trigger_type?(tt) do
    case tt do
      :VALUE_CHANGE -> true
      :VALUE_CHANGE_APPLIED -> true
      :PATH_REMOVED -> true
      _ -> false
    end
  end

  defp install_simple_triggers(realm_name, simple_trigger_maps, trigger_uuid, trigger_target) do
    Enum.reduce_while(simple_trigger_maps, :ok, fn
      simple_trigger_map, _acc ->
        %{
          object_id: object_id,
          object_type: object_type,
          simple_trigger_uuid: simple_trigger_uuid,
          simple_trigger: simple_trigger_container
        } = simple_trigger_map

        case Queries.install_simple_trigger(
               realm_name,
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

  defp install_trigger_policy_link(_realm_name, _trigger_uuid, nil) do
    :ok
  end

  defp install_trigger_policy_link(_realm_name, _trigger_uuid, "") do
    :ok
  end

  defp install_trigger_policy_link(realm_name, trigger_uuid, trigger_policy_name) do
    with :ok <- verify_trigger_policy_exists(realm_name, trigger_policy_name) do
      Queries.install_trigger_policy_link(realm_name, trigger_uuid, trigger_policy_name)
    end
  end

  def get_trigger(realm_name, trigger_name) do
    _ = Logger.debug("Get trigger.", trigger_name: trigger_name)

    with {:ok, %Trigger{} = trigger} <- Queries.retrieve_trigger(realm_name, trigger_name) do
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
            case Queries.retrieve_tagged_simple_trigger(realm_name, parent_uuid, uuid) do
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
        Logger.warn("Failed to get trigger.",
          trigger_name: trigger_name,
          tag: "get_trigger_fail"
        )

        {:error, :cannot_retrieve_simple_trigger}
      end
    end
  end

  def get_triggers_list(realm_name) do
    _ = Logger.debug("Get triggers list.")

    Queries.get_triggers_list(realm_name)
  end

  def delete_trigger(realm_name, trigger_name) do
    _ = Logger.info("Going to delete trigger.", trigger_name: trigger_name, tag: "delete_trigger")

    with {:ok, trigger} <- Queries.retrieve_trigger(realm_name, trigger_name) do
      _ =
        Logger.info("Deleting trigger.",
          trigger_name: trigger_name,
          tag: "delete_trigger_started"
        )

      delete_all_simple_triggers_succeeded =
        Enum.all?(trigger.simple_triggers_uuids, fn simple_trigger_uuid ->
          Queries.delete_simple_trigger(realm_name, trigger.trigger_uuid, simple_trigger_uuid) ==
            :ok
        end)

      delete_policy_link_succeeded =
        Queries.delete_trigger_policy_link(realm_name, trigger.trigger_uuid, trigger.policy) ==
          :ok

      if delete_all_simple_triggers_succeeded and delete_policy_link_succeeded do
        Queries.delete_trigger(realm_name, trigger_name)
      else
        Logger.warn("Failed to delete trigger.",
          trigger_name: trigger_name,
          tag: "delete_trigger_fail"
        )

        {:error, :cannot_delete_simple_trigger}
      end
    end
  end

  def install_trigger_policy(realm_name, policy_json, opts \\ []) do
    _ = Logger.info("Going to install a new trigger policy.", tag: "install_trigger_policy")

    with {:ok, json_obj} <- decode_policy(policy_json),
         policy_changeset = Policy.changeset(%Policy{}, json_obj),
         {:ok, %Policy{name: policy_name} = policy} <- validate_trigger_policy(policy_changeset),
         :ok <- verify_trigger_policy_not_exists(realm_name, policy_name) do
      _ =
        Logger.info("Installing trigger policy",
          tag: "install_policy_started",
          policy_name: policy_name
        )

      policy_proto =
        policy
        |> Policy.to_policy_proto()
        |> PolicyProto.encode()

      if opts[:async] do
        Task.start(Queries, :install_new_trigger_policy, [realm_name, policy_name, policy_proto])

        {:ok, :started}
      else
        Queries.install_new_trigger_policy(realm_name, policy_name, policy_proto)
      end
    end
  end

  defp validate_trigger_policy(policy_changeset) do
    with {:error, %Ecto.Changeset{} = changeset} <-
           Ecto.Changeset.apply_action(policy_changeset, :insert) do
      _ =
        Logger.warn("Received invalid trigger policy: #{inspect(changeset)}.",
          tag: "invalid_trigger_policy"
        )

      {:error, :invalid_trigger_policy}
    end
  end

  defp decode_policy(policy_json) do
    with {:error, {:invalid, _invalid_str, _invalid_pos}} <- Jason.decode(policy_json) do
      _ =
        Logger.warn("Received invalid trigger policy JSON: #{inspect(policy_json)}.",
          tag: "invalid_trigger_policy_json"
        )

      {:error, :invalid_trigger_policy_json}
    end
  end

  def get_trigger_policies_list(realm_name) do
    _ = Logger.debug("Get trigger policy list", tag: "get_trigger_policies_list")

    Queries.get_trigger_policies_list(realm_name)
  end

  def trigger_policy_source(realm_name, policy_name) do
    _ =
      Logger.debug("Get trigger policy source.",
        tag: "trigger_policy_source",
        policy_name: policy_name
      )

    with {:ok, policy_proto} <- fetch_trigger_policy(realm_name, policy_name) do
      policy_proto
      |> PolicyProto.decode()
      |> Policy.from_policy_proto!()
      |> Jason.encode()
    end
  end

  defp fetch_trigger_policy(realm_name, policy_name) do
    with {:error, :policy_not_found} <- Queries.fetch_trigger_policy(realm_name, policy_name) do
      Logger.warn("Trigger policy not found",
        tag: "trigger_policy_not_found",
        policy_name: policy_name
      )

      {:error, :trigger_policy_not_found}
    end
  end

  def delete_trigger_policy(realm_name, policy_name, opts \\ []) do
    _ =
      Logger.info("Going to delete trigger policy #{policy_name}",
        tag: "delete_trigger_policy",
        policy_name: policy_name
      )

    with :ok <- verify_trigger_policy_exists(realm_name, policy_name),
         {:ok, false} <- check_trigger_policy_has_triggers(realm_name, policy_name) do
      if opts[:async] do
        Task.start_link(Engine, :execute_trigger_policy_deletion, [realm_name, policy_name])

        {:ok, :started}
      else
        Engine.execute_trigger_policy_deletion(realm_name, policy_name)
      end
    end
  end

  defp verify_trigger_policy_not_exists(realm_name, policy_name) do
    with {:ok, exists?} <- Queries.check_trigger_policy_already_present(realm_name, policy_name) do
      if not exists? do
        :ok
      else
        Logger.warn("Trigger policy #{policy_name} already present",
          tag: "trigger_policy_already_present"
        )

        {:error, :trigger_policy_already_present}
      end
    end
  end

  defp verify_trigger_policy_exists(realm_name, policy_name) do
    with {:ok, exists?} <- Queries.check_trigger_policy_already_present(realm_name, policy_name) do
      if exists? do
        :ok
      else
        Logger.warn("Trigger policy #{policy_name} not found",
          tag: "trigger_policy_not_found"
        )

        {:error, :trigger_policy_not_found}
      end
    end
  end

  defp check_trigger_policy_has_triggers(realm_name, policy_name) do
    with {:ok, true} <- Queries.check_policy_has_triggers(realm_name, policy_name) do
      Logger.warn("Trigger policy #{policy_name} is currently being used by triggers",
        tag: "cannot_delete_currently_used_trigger_policy"
      )

      {:error, :cannot_delete_currently_used_trigger_policy}
    end
  end

  def execute_trigger_policy_deletion(realm_name, policy_name) do
    _ =
      Logger.info("Trigger policy deletion started.",
        policy_name: policy_name,
        tag: "delete_trigger_policy_started"
      )

    Queries.delete_trigger_policy(realm_name, policy_name)
  end
end
