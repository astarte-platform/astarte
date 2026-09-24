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

defmodule Astarte.Core.Generators.Triggers.SimpleConfigs.ScopeTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.Generators.Triggers.SimpleConfigs.Scope

  alias Astarte.Core.Device
  alias Astarte.Core.Group

  describe "triggers scope generator" do
    property "generates the any-device scope" do
      check all scope <- trigger_scope(type: :any_device) do
        assert scope == %{}
      end
    end

    property "generates a valid device scope" do
      check all %{device_id: device_id} = scope <- trigger_scope(type: :device) do
        assert scope == %{device_id: device_id}
        assert {:ok, _device_id} = Device.decode_device_id(device_id)
      end
    end

    property "generates a valid group scope" do
      check all %{group_name: group_name} = scope <- trigger_scope(type: :group) do
        assert scope == %{group_name: group_name}
        assert Group.valid_name?(group_name)
      end
    end
  end
end
