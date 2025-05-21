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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.AppEngine.API.RPC.DataUpdaterPlant.InstallVolatileTrigger.RequestData do
  @moduledoc false

  defstruct [
    :realm_name,
    :device_id,
    :object_id,
    :object_type,
    :parent_id,
    :simple_trigger,
    :simple_trigger_id,
    :trigger_target
  ]

  # TODO: actually type things
  @type t() :: %__MODULE__{
          realm_name: String.t(),
          device_id: binary(),
          object_id: binary(),
          object_type: integer(),
          parent_id: term(),
          simple_trigger: term(),
          simple_trigger_id: term(),
          trigger_target: term()
        }
end
