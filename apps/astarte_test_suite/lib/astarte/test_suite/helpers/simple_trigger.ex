#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.TestSuite.Helpers.SimpleTrigger do
  @moduledoc false

  import StreamData, only: [bind: 2, constant: 1, one_of: 1]

  import Astarte.Core.Generators.Triggers.AMQPTriggerTarget,
    only: [amqp_trigger_target: 1]

  import Astarte.Core.Generators.Triggers.SimpleConfigs.DataTriggerConfig,
    only: [data_trigger_config: 1]

  import Astarte.Core.Generators.Triggers.SimpleConfigs.DeviceTriggerConfig,
    only: [device_trigger_config: 1]

  import Astarte.Core.Generators.Triggers.SimpleConfigs.SimpleTriggerConfig,
    only: [simple_trigger_config: 1]

  import Astarte.DataAccess.Adapters.Triggers.SimpleTrigger,
    only: [from_core_simple_trigger_to_change: 1]

  import Astarte.TestSuite.CaseContext, only: [get!: 3, put!: 5, put_fixture: 3, reduce: 4]

  alias Astarte.Core.Triggers.Trigger
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm, as: RealmData
  alias Astarte.DataAccess.Realms.SimpleTrigger, as: SimpleTriggerData
  alias Astarte.DataAccess.Repo

  def simple_triggers(context) do
    reduce(context, :triggers, context, fn trigger_id, trigger, _realm_id, acc ->
      put_simple_triggers(acc, trigger, trigger_id)
    end)
  end

  def data(%{triggers: triggers} = context) do
    results =
      reduce(
        context,
        :simple_triggers,
        [],
        fn _simple_trigger_id, simple_trigger, trigger_id, results ->
          [persist_simple_trigger!(context, triggers, simple_trigger, trigger_id) | results]
        end
      )

    put_fixture(context, :simple_trigger_data, %{
      simple_trigger_database_results: results,
      simple_triggers_registered?: true
    })
  end

  defp put_simple_triggers(
         context,
         %Trigger{simple_triggers_uuids: simple_trigger_ids, trigger_uuid: trigger_uuid},
         trigger_id
       ),
       do: put_simple_triggers(context, simple_trigger_ids, trigger_uuid, trigger_id)

  defp put_simple_triggers(context, [], _trigger_uuid, _trigger_id), do: context

  defp put_simple_triggers(
         context,
         [simple_trigger_id | simple_trigger_ids],
         trigger_uuid,
         trigger_id
       ) do
    simple_trigger = simple_trigger(trigger_uuid, simple_trigger_id)
    id = Ecto.UUID.load!(simple_trigger_id)

    context
    |> put!(:simple_triggers, id, simple_trigger, trigger_id)
    |> put_simple_triggers(simple_trigger_ids, trigger_uuid, trigger_id)
  end

  defp simple_trigger(parent_trigger_id, simple_trigger_id) do
    %{
      simple_trigger_config: realm_wide_simple_trigger_config() |> Enum.at(0),
      trigger_target:
        amqp_trigger_target(
          parent_trigger_id: parent_trigger_id,
          simple_trigger_id: simple_trigger_id
        )
        |> Enum.at(0)
    }
  end

  defp realm_wide_simple_trigger_config do
    [realm_wide_data_trigger_config(), realm_wide_device_trigger_config()]
    |> one_of()
  end

  defp realm_wide_data_trigger_config do
    data_trigger_config(scope: %{}, interface: constant(:any_interface))
    |> bind(&simple_trigger_config(simple_trigger: constant({:data_trigger, &1})))
  end

  defp realm_wide_device_trigger_config do
    device_trigger_config(scope: %{}, device_event_type: constant(:DEVICE_CONNECTED))
    |> bind(&simple_trigger_config(simple_trigger: constant({:device_trigger, &1})))
  end

  defp persist_simple_trigger!(context, triggers, simple_trigger, trigger_id) do
    {_trigger, realm_id} = Map.fetch!(triggers, trigger_id)
    %{id: realm_name} = get!(context, :realms, realm_id)

    %{simple_trigger: simple_trigger_changes, simple_trigger_reference: reference_changes} =
      from_core_simple_trigger_to_change(simple_trigger)

    opts = [
      prefix: RealmData.keyspace_name(realm_name),
      consistency: Consistency.domain_model(:write)
    ]

    simple_trigger_result = Repo.insert!(struct(SimpleTriggerData, simple_trigger_changes), opts)
    :ok = KvStore.insert(reference_changes, opts)

    %{simple_trigger: simple_trigger_result, simple_trigger_reference: reference_changes}
  end
end
