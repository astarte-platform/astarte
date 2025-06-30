#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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
  alias Astarte.Core.Device
  alias Astarte.RealmManagement.Queries

  def install_interface(realm_name, interface_json, opts \\ []) do
    _ = Logger.info("Going to install a new interface.", tag: "install_interface")

    with {:ok, json_obj} <- Jason.decode(interface_json),
         interface_changeset <- InterfaceDocument.changeset(%InterfaceDocument{}, json_obj),
         {:ok, interface_doc} <- Ecto.Changeset.apply_action(interface_changeset, :insert),
         :ok <- verify_mappings_max_storage_retention(realm_name, interface_doc),
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
          Logger.warning("Received invalid interface JSON: #{inspect(interface_json)}.",
            tag: "invalid_json"
          )

        {:error, :invalid_interface_document}

      {:error, %Ecto.Changeset{} = changeset} ->
        _ =
          Logger.warning("Received invalid interface: #{inspect(changeset)}.",
            tag: "invalid_interface_document"
          )

        {:error, :invalid_interface_document}

      {:error, :database_connection_error} ->
        {:error, :realm_not_found}

      {:error, :database_error} ->
        {:error, :database_error}

      {:interface_avail, {:ok, true}} ->
        {:error, :already_installed_interface}

      {:error, :maximum_database_retention_exceeded} ->
        {:error, :maximum_database_retention_exceeded}

      {:error, :interface_name_collision} ->
        {:error, :interface_name_collision}

      {:error, :overlapping_mappings} ->
        {:error, :overlapping_mappings}
    end
  end

  def interface_source(realm_name, interface_name, major_version) do
    _ =
      Logger.debug("Get interface source.",
        interface: interface_name,
        interface_major: major_version
      )

    with {:ok, interface} <- Queries.fetch_interface(realm_name, interface_name, major_version) do
      Jason.encode(interface)
    end
  end

  def get_interfaces_list(realm_name) do
    _ = Logger.debug("Get interfaces list.")

    Queries.get_interfaces_list(realm_name)
  end

  def get_jwt_public_key_pem(realm_name) do
    _ = Logger.debug("Get JWT public key PEM.")

    Queries.get_jwt_public_key_pem(realm_name)
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
         :ok <-
           install_trigger_policy_link(realm_name, trigger_uuid, trigger_policy_name) do
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

  defp validate_simple_trigger(_client, %DataTrigger{interface_name: "*"}) do
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

    # This should fail with {:error, :interface_not_found} if the interface does not exist
    with {:ok, interface} <-
           Queries.fetch_interface(realm_name, interface_name, interface_major) do
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

  defp validate_simple_trigger(_client, _other_trigger) do
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
        Logger.warning("Failed to get trigger.",
          trigger_name: trigger_name,
          tag: "get_trigger_fail"
        )

        {:error, :cannot_retrieve_simple_trigger}
      end
    end
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
          Queries.delete_simple_trigger(
            realm_name,
            trigger.trigger_uuid,
            simple_trigger_uuid
          ) == :ok
        end)

      delete_policy_link_succeeded =
        Queries.delete_trigger_policy_link(realm_name, trigger.trigger_uuid, trigger.policy) ==
          :ok

      if delete_all_simple_triggers_succeeded and delete_policy_link_succeeded do
        Queries.delete_trigger(realm_name, trigger_name)
      else
        Logger.warning("Failed to delete trigger.",
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
        Logger.warning("Received invalid trigger policy: #{inspect(changeset)}.",
          tag: "invalid_trigger_policy"
        )

      {:error, :invalid_trigger_policy}
    end
  end

  defp decode_policy(policy_json) do
    with {:error, {:invalid, _invalid_str, _invalid_pos}} <- Jason.decode(policy_json) do
      _ =
        Logger.warning("Received invalid trigger policy JSON: #{inspect(policy_json)}.",
          tag: "invalid_trigger_policy_json"
        )

      {:error, :invalid_trigger_policy_json}
    end
  end

  defp verify_mappings_max_storage_retention(realm_name, interface) do
    with {:ok, max_retention} <- get_datastream_maximum_storage_retention(realm_name) do
      if mappings_retention_valid?(interface.mappings, max_retention) do
        :ok
      else
        {:error, :maximum_database_retention_exceeded}
      end
    end
  end

  defp mappings_retention_valid?(_mappings, 0), do: true

  defp mappings_retention_valid?(mappings, max_retention) do
    Enum.all?(mappings, fn %Mapping{database_retention_ttl: retention} ->
      retention <= max_retention
    end)
  end

  defp verify_trigger_policy_not_exists(realm_name, policy_name) do
    with {:ok, exists?} <- Queries.check_trigger_policy_already_present(realm_name, policy_name) do
      if not exists? do
        :ok
      else
        Logger.warning("Trigger policy #{policy_name} already present",
          tag: "trigger_policy_already_present"
        )

        {:error, :trigger_policy_already_present}
      end
    end
  end

  defp verify_trigger_policy_exists(client, policy_name) do
    with {:ok, exists?} <- Queries.check_trigger_policy_already_present(client, policy_name) do
      if exists? do
        :ok
      else
        Logger.warning("Trigger policy #{policy_name} not found",
          tag: "trigger_policy_not_found"
        )

        {:error, :trigger_policy_not_found}
      end
    end
  end

  @doc """
  Starts the deletion of a device. Deletion is carried out asynchronously.
  The device removal scheduler will take care of eventually deleting the device.
  See Astarte.RealmManagement.DeviceRemoval.Scheduler.
  Returns `:ok` or `{:error, reason}`.
  """
  @spec delete_device(binary(), Device.encoded_device_id()) :: :ok | {:error, any()}
  def delete_device(realm_name, device_id) do
    # TODO check that realm exists, too
    with {:ok, decoded_device_id} <-
           Astarte.Core.Device.decode_device_id(device_id, allow_extended_id: true),
         {:ok, true} <- check_device_exists(realm_name, decoded_device_id),
         :ok <- insert_device_into_deletion_in_progress(realm_name, decoded_device_id) do
      _ = Logger.info("Added device #{device_id} to deletion in progress")
      :ok
    end
  end

  defp check_device_exists(realm_name, device_id) do
    case Queries.check_device_exists(realm_name, device_id) do
      {:ok, true} ->
        {:ok, true}

      {:ok, false} ->
        _ =
          Logger.warning(
            "Device #{inspect(device_id)} does not exist",
            tag: "device_not_found"
          )

        {:error, :device_not_found}

      {:error, reason} ->
        Logger.warning(
          "Cannot check if device #{inspect(device_id)} exists, reason #{inspect(reason)}",
          tag: "device_exists_fail"
        )

        {:error, reason}
    end
  end

  defp insert_device_into_deletion_in_progress(realm_name, device_id) do
    with {:error, reason} <-
           Queries.insert_device_into_deletion_in_progress(realm_name, device_id) do
      _ =
        Logger.warning(
          "Cannot start deletion of device #{inspect(device_id)}, reason #{inspect(reason)}",
          tag: "insert_device_into_deleted_fail"
        )

      {:error, reason}
    end
  end

  @doc """
  Retrieves the device registration limit of a realm.
  Returns either `{:ok, limit}` or `{:error, reason}`.
  The limit is an integer (if set) or `nil` (if unset).
  """
  @spec get_device_registration_limit(String.t()) ::
          {:ok, integer()} | {:ok, nil} | {:error, atom()}
  def get_device_registration_limit(realm_name) do
    case Queries.get_device_registration_limit(realm_name) do
      {:ok, value} ->
        {:ok, value}

      {:error, reason} ->
        _ =
          Logger.warning(
            "Cannot get device registration limit for realm #{realm_name}",
            tag: "get_device_registration_limit_fail"
          )

        {:error, reason}
    end
  end

  @doc """
  Retrieves the maximum datastream storage retention of a realm.
  Returns either `{:ok, limit}` or `{:error, reason}`.
  The limit is a strictly positive integer (if set), 0 if unset.
  """
  @spec get_datastream_maximum_storage_retention(String.t()) ::
          {:ok, non_neg_integer()} | {:error, atom()}
  def get_datastream_maximum_storage_retention(realm_name) do
    case Queries.get_datastream_maximum_storage_retention(realm_name) do
      {:ok, value} ->
        {:ok, value}

      {:error, reason} ->
        _ =
          Logger.warning(
            "Cannot get maximum datastream storage retention for realm #{realm_name}",
            tag: "get_datastream_maximum_storage_retention_fail"
          )

        {:error, reason}
    end
  end
end
