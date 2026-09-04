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

defmodule Astarte.Core.Generators.Triggers.TriggerTargetContainer do
  @moduledoc """
  Generates trigger target containers.
  """
  use Astarte.Generators.Utilities.ParamsGen

  import Astarte.Core.Generators.Triggers.AMQPTriggerTarget

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TriggerTargetContainer

  @doc """
  Generates a trigger target container wrapping an AMQP trigger target.
  """
  @spec trigger_target_container() :: StreamData.t(TriggerTargetContainer.t())
  @spec trigger_target_container(params :: keyword()) :: StreamData.t(TriggerTargetContainer.t())
  def trigger_target_container(params \\ []) do
    params gen all version <- constant(0),
                   trigger_target <- amqp_trigger_target(),
                   params: params do
      %TriggerTargetContainer{
        version: version,
        trigger_target: {:amqp_trigger_target, trigger_target}
      }
    end
  end
end
