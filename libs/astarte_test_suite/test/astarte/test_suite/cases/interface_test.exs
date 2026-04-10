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

defmodule Astarte.TestSuite.Cases.InterfaceTest do
  use ExUnit.Case, async: true

  import Astarte.TestSuite.CaseContext

  alias Astarte.Core.Interface

  alias Astarte.TestSuite.Cases.Interface, as: InterfaceCase

  test "normalizes interface defaults" do
    assert InterfaceCase.normalize_config!([], realm_context()).interfaces |> map_size() == 3
  end

  test "normalizes interface count configuration" do
    assert InterfaceCase.normalize_config!([interface_number: 1], realm_context()).interfaces
           |> map_size() == 1
  end

  test "normalizes generated core interfaces" do
    assert InterfaceCase.normalize_config!([interface_number: 1], realm_context()).interfaces
           |> Map.values()
           |> hd()
           |> elem(0)
           |> is_struct(Interface)
  end

  test "keeps explicit interfaces" do
    interfaces = %{
      "org.example.Interface" => {%Interface{name: "org.example.Interface"}, "realm1"}
    }

    assert InterfaceCase.normalize_config!(
             [interfaces: interfaces],
             realm_context()
           ).interfaces == %{
             "org.example.Interface" => {%Interface{name: "org.example.Interface"}, "realm1"}
           }
  end

  test "rejects removed interface prefix configuration" do
    assert_raise ArgumentError, ~r/unknown configuration keys \[:interface_prefix\]/, fn ->
      InterfaceCase.normalize_config!([interface_prefix: "org.example"], realm_context())
    end
  end

  defp realm_context do
    %{}
    |> put!(:instances, "astarte1", "astarte1", nil)
    |> put!(:realms, "realm1", %{id: "realm1", instance_id: "astarte1"}, "astarte1")
  end
end
