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

defmodule Astarte.Events.Triggers.DataTriggerContext do
  @moduledoc """
  Module representing the context of a data trigger event in Astarte Events.
  """

  alias Astarte.DataAccess.UUID
  alias Astarte.Events.Triggers.Core

  use TypedStruct

  typedstruct do
    field :realm_name, String.t()
    field :device_id, UUID.t()
    field :groups, [String.t()]
    field :event, Core.data_trigger_event()
    field :interface_id, UUID.t()
    field :endpoint_id, UUID.t()
    field :path, String.t() | nil
    field :value, term() | nil
    field :data, Core.fetch_triggers_data()
  end
end
