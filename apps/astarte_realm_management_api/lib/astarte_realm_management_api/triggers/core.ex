#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.RealmManagement.API.Triggers.Core do
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.SimpleTriggerContainer
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer
  alias Astarte.Core.Triggers.Trigger
  alias Astarte.RealmManagement.API.Triggers.Queries

  require Logger

  def get_trigger(realm_name, trigger_name) do
    with {:ok, trigger} <- Queries.retrieve_trigger(realm_name, trigger_name) do
      %Trigger{
        trigger_uuid: parent_uuid,
        simple_triggers_uuids: simple_triggers_uuids
      } = trigger

      initial_acc = {:ok, %{trigger: trigger, tagged_simple_triggers: []}}

      # TODO: use batch
      Enum.reduce_while(simple_triggers_uuids, initial_acc, fn uuid, {:ok, acc} ->
        case Queries.retrieve_tagged_simple_trigger(realm_name, parent_uuid, uuid) do
          {:ok, %TaggedSimpleTrigger{} = result} ->
            tagged_simple_triggers = [result | acc.tagged_simple_triggers]
            acc = %{acc | tagged_simple_triggers: tagged_simple_triggers}
            {:cont, {:ok, acc}}

          _error ->
            Logger.warning("Failed to get trigger.",
              trigger_name: trigger_name,
              tag: "get_trigger_fail"
            )

            {:halt, {:error, :cannot_retrieve_simple_trigger}}
        end
      end)
    end
  end

  def install_trigger(
        realm_name,
        trigger_name,
        trigger_policy_name,
        action,
        tagged_simple_triggers
      ) do
    _ =
      Logger.info("Going to install a new trigger.",
        trigger_name: trigger_name,
        tag: "install_trigger"
      )

    with :ok <- check_trigger_does_not_exitst(realm_name, trigger_name),
         simple_trigger_maps = build_simple_trigger_maps(tagged_simple_triggers),
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
    end
  end

  defp check_trigger_does_not_exitst(realm_name, trigger_name) do
    case Queries.retrieve_trigger_uuid(realm_name, trigger_name) do
      {:error, :trigger_not_found} -> :ok
      {:ok, _} -> {:error, :already_installed_trigger}
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

  defp build_simple_trigger_maps(tagged_simple_triggers) do
    for tagged_simple_trigger <- tagged_simple_triggers do
      %TaggedSimpleTrigger{
        object_id: object_id,
        object_type: object_type,
        simple_trigger_container: simple_trigger_container
      } = tagged_simple_trigger

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
end
