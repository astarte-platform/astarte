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

defmodule Astarte.Core.Generators.Triggers.TaggedSimpleTrigger do
  @moduledoc """
  Generates tagged simple triggers from valid simple trigger configurations.
  """
  use Astarte.Generators.Utilities.ParamsGen

  import Astarte.Core.Generators.Triggers.SimpleTriggerConfig

  alias Astarte.Core.Triggers.SimpleTriggerConfig
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger

  @doc """
  Generates a tagged simple trigger.

  The `config` parameter can be used to derive the protobuf from a specific simple trigger
  configuration.
  """
  @spec tagged_simple_trigger() :: StreamData.t(TaggedSimpleTrigger.t())
  @spec tagged_simple_trigger(params :: keyword()) :: StreamData.t(TaggedSimpleTrigger.t())
  def tagged_simple_trigger(params \\ []) do
    params gen all config <- simple_trigger_config(),
                   params: params do
      config
      |> SimpleTriggerConfig.to_tagged_simple_trigger()
      |> TaggedSimpleTrigger.encode()
      |> TaggedSimpleTrigger.decode()
    end
  end
end
