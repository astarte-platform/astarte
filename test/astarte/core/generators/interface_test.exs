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

  alias Ecto.Changeset
  alias Astarte.Core.Interface
  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator

  @moduletag :interface

  @doc """
  Property test for Astarte Interface generator.
  """
  describe "interface generator" do
    property "validate interface" do
      check all(interface <- InterfaceGenerator.interface()) do
        %Changeset{valid?: valid, errors: errors} = Interface.changeset(interface)

        assert valid, "Invalid interface: " <> (errors |> Enum.join(", "))
      end
    end
  end
end
