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

defmodule Astarte.Events.Triggers.DataTrigger do
  @moduledoc """
   Module representing a data trigger in Astarte Events.
  """
  use TypedStruct
  alias Astarte.Core.Triggers.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget
  alias __MODULE__, as: DataTriggerWithPolicy

  @type core_without_targets() :: %DataTrigger{trigger_targets: nil}
  @type policy_name() :: String.t() | nil
  @type target_and_policy() :: {AMQPTriggerTarget.t(), policy_name()}
  @type trigger_id_to_policy_name() :: %{Astarte.DataAccess.UUID.t() => String.t()}
  @type path_match_tokens() :: :any_endpoint | [String.t()]

  typedstruct do
    field :interface_id, DataTrigger.interface_id()
    field :path_match_tokens, path_match_tokens()
    field :value_match_operator, DataTrigger.value_match_operator()
    field :known_value, DataTrigger.known_value()
    field :trigger_targets, [target_and_policy()], enforce: true
  end

  defdelegate are_congruent?(trigger_a, trigger_b), to: DataTrigger

  @spec from_core(DataTrigger.t(), trigger_id_to_policy_name) :: t()
  @spec from_core(core_without_targets(), trigger_id_to_policy_name) :: t()
  def from_core(data_trigger, trigger_id_to_policy_name) do
    %DataTrigger{
      interface_id: interface_id,
      path_match_tokens: path_match_tokens,
      value_match_operator: value_match_operator,
      known_value: known_value,
      trigger_targets: trigger_targets
    } = data_trigger

    targets_with_policies =
      for target <- List.wrap(trigger_targets) do
        policy = Map.get(trigger_id_to_policy_name, target.parent_trigger_id)
        {target, policy}
      end

    %DataTriggerWithPolicy{
      interface_id: interface_id,
      path_match_tokens: path_match_tokens,
      value_match_operator: value_match_operator,
      known_value: known_value,
      trigger_targets: targets_with_policies
    }
  end
end
