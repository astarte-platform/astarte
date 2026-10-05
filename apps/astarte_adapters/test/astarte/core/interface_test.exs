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

defmodule Astarte.Core.Adapters.InterfaceTest do
  use ExUnit.Case
  use ExUnitProperties

  import Astarte.Core.Generators.Interface

  import Astarte.Core.Adapters.Interface

  alias Ecto.Changeset

  alias Astarte.Core.Interface

  @doc false
  @moduletag :core
  @moduletag :interface
  describe "integration tests" do
    @describetag :it

    property "validate interface using Changeset" do
      check all interface <- interface() do
        changeset = Interface.changeset(%Interface{}, from_core_interface_to_change(interface))

        assert %Changeset{valid?: true} = changeset,
               "Invalid interface: #{inspect(changeset.errors)}"
      end
    end

    property "allows the resulting map to be json encoded" do
      check all interface <- interface() do
        changeset = Interface.changeset(%Interface{}, from_core_interface_to_change(interface))

        assert {:ok, _json} = changeset |> Changeset.apply_changes() |> Jason.encode()
      end
    end

    @tag issue: 45
    property "custom interface creation" do
      check all interface <-
                  interface(
                    type: :datastream,
                    aggregation: :object,
                    explicit_timestamp: true
                  ) do
        changeset = Interface.changeset(%Interface{}, from_core_interface_to_change(interface))
        assert changeset.valid?, "Invalid interface: #{inspect(changeset.errors)}"
      end
    end
  end
end
