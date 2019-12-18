#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.AppEngine.API.RPC.DataUpdaterPlant.VolatileTrigger do
  @enforce_keys [
    :object_id,
    :object_type,
    :serialized_simple_trigger,
    :parent_id,
    :simple_trigger_id,
    :serialized_trigger_target
  ]
  defstruct @enforce_keys
end
