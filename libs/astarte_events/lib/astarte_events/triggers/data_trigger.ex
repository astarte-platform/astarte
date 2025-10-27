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
  use TypedStruct
  alias Astarte.Core.Triggers.DataTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget

  @type policy_name() :: String.t() | nil
  @type target_and_policy() :: {AMQPTriggerTarget.t(), policy_name()}

  typedstruct do
    field :interface_id, DataTrigger.interface_id()
    field :path_match_tokens, DataTrigger.path_match_tokens()
    field :value_match_operator, DataTrigger.value_match_operator()
    field :known_value, DataTrigger.known_value()
    field :trigger_targets, [target_and_policy()], enforce: true
  end

  defdelegate are_congruent?(trigger_a, trigger_b), to: DataTrigger
end
