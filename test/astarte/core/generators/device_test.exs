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

defmodule Astarte.Core.Generators.DeviceTest do
  @moduledoc """
  Tests for Astarte Device generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Ecto.Changeset
  alias Astarte.Core.Interface
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.Device, as: DeviceGenerator

  @moduletag :device

  @doc """
  Property test for Astarte Device generator.
  """
  describe "device generator" do
    property "validate device" do
      check all(
              interfaces <- InterfaceGenerator.interface(),
              device <- DeviceGenerator.device([])
            ) do
        assert true
      end
    end
  end
end
