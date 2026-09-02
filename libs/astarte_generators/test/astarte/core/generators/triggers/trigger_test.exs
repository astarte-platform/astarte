#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.Core.Generators.Triggers.TriggerTest do
  @moduledoc false
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Triggers.Trigger

  alias Astarte.Core.Triggers.Trigger

  @trigger_uuid <<5, 94, 105, 231, 207, 92, 65, 80, 150, 231, 248, 187, 116, 95, 143, 49>>
  @simple_trigger_uuid <<150, 67, 77, 67, 99, 180, 73, 104, 191, 225, 11, 143, 30, 171, 126, 0>>
  @action ~s({"http_url":"https://example.com","http_method":"post"})

  describe "trigger generator" do
    property "generates serializable triggers with valid HTTP actions" do
      check all trigger <- trigger() do
        %Trigger{
          trigger_uuid: trigger_uuid,
          simple_triggers_uuids: simple_triggers_uuids,
          action: action,
          name: name,
          policy: policy
        } = trigger

        action = Jason.decode!(action)
        %URI{scheme: scheme} = action |> Map.fetch!("http_url") |> URI.parse()

        assert trigger == trigger |> Trigger.encode() |> Trigger.decode() and
                 uuid_v4?(trigger_uuid) and
                 Enum.all?(simple_triggers_uuids, &uuid_v4?/1) and
                 Map.fetch!(action, "http_method") in ~w(delete get head options patch post put) and
                 scheme in ["http", "https"] and
                 byte_size(name) in 1..128 and
                 is_nil(policy)
      end
    end

    test "preserves correlated identifiers and policy names supplied for seeding" do
      assert %Trigger{
               version: 0,
               trigger_uuid: @trigger_uuid,
               simple_triggers_uuids: [@simple_trigger_uuid],
               action: @action,
               name: "seeded_trigger",
               policy: "delivery_policy"
             } =
               trigger(
                 trigger_uuid: @trigger_uuid,
                 simple_triggers_uuids: [@simple_trigger_uuid],
                 action: @action,
                 name: "seeded_trigger",
                 policy: "delivery_policy"
               )
               |> Enum.at(0)
    end
  end

  defp uuid_v4?(<<_prefix::48, 4::4, _middle::12, 2::2, _suffix::62>>), do: true
  defp uuid_v4?(_uuid), do: false
end
