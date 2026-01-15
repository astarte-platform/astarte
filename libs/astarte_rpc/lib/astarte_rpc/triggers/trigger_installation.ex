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

defmodule Astarte.RPC.Triggers.TriggerInstallation do
  use TypedStruct

  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.TaggedSimpleTrigger
  alias Astarte.Core.Triggers.SimpleTriggersProtobuf.AMQPTriggerTarget

  @type trigger_target :: AMQPTriggerTarget.t()

  typedstruct do
    field :realm_name, String.t()
    field :simple_trigger, TaggedSimpleTrigger.t()
    field :target, trigger_target()
    field :policy, String.t() | nil
    field :data, Astarte.Events.Triggers.Core.fetch_triggers_data()
  end
end
