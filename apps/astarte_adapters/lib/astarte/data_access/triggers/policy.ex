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

defmodule Astarte.DataAccess.Adapters.Triggers.Policy do
  @moduledoc """
  Mapping to Astarte.DataAccess.KvStore
  """
  use Astarte.Adapters

  alias Astarte.Core.Triggers.Policy
  alias Astarte.Core.Triggers.PolicyProtobuf.Policy, as: PolicyProtobuf

  transform from_core_triggers_policy_to_change do
    @source Policy.t()
    @returns map()

    pre_process &pre_process/1

    keep :group

    field :key <- :name
    field :value, &encoded_policy/1
  end

  defp pre_process(%Policy{} = policy), do: Map.put(policy, :group, "trigger_policy")

  defp encoded_policy(policy), do: policy |> Policy.to_policy_proto() |> PolicyProtobuf.encode()
end
