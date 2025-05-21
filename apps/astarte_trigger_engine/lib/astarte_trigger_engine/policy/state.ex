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

defmodule Astarte.TriggerEngine.Policy.State do
  use TypedStruct

  alias Astarte.Core.Triggers.Policy

  @type message_id() :: term()
  @type retry_map() :: %{message_id() => pos_integer()}

  typedstruct do
    field :retry_map, retry_map()
    field :policy, Policy.t()
  end
end
