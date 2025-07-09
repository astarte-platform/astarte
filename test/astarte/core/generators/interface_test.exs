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

defmodule Astarte.Core.Generators.InterfaceTest do
  @moduledoc """
  Tests for Astarte Interface generator.
  """
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Interface

  @moduletag :core
  @moduletag :interface

  @doc false
  describe "interface generator" do
    @describetag :success
    @describetag :ut

    property "validate interface using Changeset" do
      gen_interface_changes = InterfaceGenerator.interface() |> InterfaceGenerator.to_changes()

      check all changes <- gen_interface_changes do
        changeset = Interface.changeset(%Interface{}, changes)
        assert changeset.valid?, "Invalid interface: #{inspect(changeset.errors)}"
      end
    end

    @tag issue: 45
    property "custom interface creation" do
      gen_interface_changes =
        InterfaceGenerator.interface(
          type: :datastream,
          aggregation: :object,
          explicit_timestamp: true
        )
        |> InterfaceGenerator.to_changes()

      check all changes <- gen_interface_changes do
        changeset = Interface.changeset(%Interface{}, changes)
        assert changeset.valid?, "Invalid interface: #{inspect(changeset.errors)}"
      end
    end
  end
end
