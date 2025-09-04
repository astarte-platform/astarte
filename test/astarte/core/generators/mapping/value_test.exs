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

defmodule Astarte.Core.Generators.Mapping.ValueTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping
  alias Astarte.Core.Mapping.ValueType

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.Mapping.Value, as: ValueGenerator

  @moduletag :mapping
  @moduletag :value

  @endpoints_path [
    {:individual, "/%{param}", "/abc", true},
    {:object, "/%{param}/a", "/dce", true},
    {:individual, "/Alpha/Beta/Gamma", "/Alpha/Beta/Gamma", true},
    {:individual, "/Alpha/Beta/Gamma", "/Alpha/Beta", false},
    {:individual, "/Shop/Prd45/Details", "/shop/Prd45/Details", false},
    {:individual, "/api/v1/users/%{UID}/orders/%{OID}/lines/LID",
     "/api/v1/users/U9/orders/O77/lines/LID", true},
    {:individual, "/api/v1/users/%{UID}/orders/%{OID}/lines/LID",
     "/api/v1/users/U9/orders/O77/lines", false},
    {:object, "/Catalog/%{Section}/Items", "/Catalog/Electronics", true},
    {:object, "/Catalog/%{Section}/Items", "/Catalog/Electronics/Items", false},
    {:object, "/Foo/%{Id}/Bar", "/Foo/A1", true},
    {:object, "/Foo/%{Id}/Bar", "/Foo/A1/B2", false},
    {:individual, "/User_Profile/%{UID123}/Orders/%{YEAR}/Summary",
     "/User_Profile/A7/Orders/2025/Summary", true},
    {:individual, "/User_Profile/%{UID123}/Orders/%{YEAR}/Summary",
     "/User_Profile/A7/Orders/2025", false},
    {:individual, "/Srv/%{Env}/Cfg/%{Key}/Apply", "/Srv/Prod/Cfg/DB1/Apply", true},
    {:individual, "/Srv/%{Env}/Cfg/%{Key}/Apply", "/Srv/Prod/Cfg/DB1/Apply/Now", false},
    {:individual, "/Root/%{A}/%{B}/%{C}/Leaf", "/Root/x1/y2/z3/Leaf", true},
    {:object, "/Root/%{A}/%{B}/%{C}/Leaf", "/Root/x1/y2/z3", true},
    {:object, "/Root/%{A}/%{B}/%{C}/Leaf", "/Root/x1/y2", false},
    {:individual, "/Alpha/%{X}/Beta/%{Y}/Gamma", "/Alpha/aa1/Beta/bb2/Gamma", true},
    {:individual, "/Alpha/%{X}/Beta/%{Y}/Gamma", "/Alpha/aa1/Beta/Gamma", false},
    {:individual, "/A_/B_/C_/D_/E_", "/A_/B_/C_/D_/E_", true},
    {:individual, "/A_/B_/C_/D_/E_", "/A_/B_/C_/D_", false},
    {:individual, "/calc/%{Mode}/run/Now", "/calc/Fast/run/Now", true},
    {:individual, "/calc/%{Mode}/run/Now", "/calc/Fast/run", false},
    {:object, "/calc/%{Mode}/run/Now", "/calc/Fast/run", true},
    {:individual, "/Auth/Login/Step/N", "/Auth/Login/Step/N", true},
    {:individual, "/Auth/Login/Step/N", "/Auth/Login/Step2", false},
    {:individual, "/node/%{N1}/leaf/%{L2}/x/K", "/node/N/leaf/L/x/K", true},
    {:object, "/node/%{N1}/leaf/%{L2}/x/K", "/node/N/leaf/L/x", true},
    {:individual, "/Lib/%{Pkg}/v/%{Major}/_/_Minor", "/Lib/core/v/1/_/_Minor", true},
    {:individual, "/Lib/%{Pkg}/v/%{Major}/_/_Minor", "/Lib/core/v/1", false},
    {:individual, "/xY/%{Za}/Q1/%{Rb}/Zz", "/xY/za1/Q1/rb2/Zz", true},
    {:individual, "/xY/%{Za}/Q1/%{Rb}/Zz", "/xY/za1/Q1/rb2/ZZ", false},
    {:object, "/alpha/%{A1}/beta/%{B2}/gamma", "/alpha/x1/beta/y2", true},
    {:object, "/alpha/%{A1}/beta/%{B2}/gamma", "/alpha/x1/beta", false},
    {:individual, "/srv/%{EnvX}/cfg/%{KeyX}/edit/User", "/srv/Dev/cfg/DB2/edit/User", true},
    {:individual, "/srv/%{EnvX}/cfg/%{KeyX}/edit/User", "/srv/Dev/cfg/DB2/edit", false},
    {:individual, "/AA/BB/CC/%{DD}/EE/FF", "/AA/BB/CC/d1/EE/FF", true},
    {:object, "/AA/BB/CC/%{DD}/EE/FF", "/AA/BB/CC/d1/EE", true},
    {:individual, "/Path/%{A}/To/%{B}/Res/%{C}/View", "/Path/A1/To/B2/Res/C3/View", true},
    {:individual, "/Path/%{A}/To/%{B}/Res/%{C}/View", "/Path/A1/To/B2/Res/C3/View/", false},
    {:individual, "/ROOT/%{X}/MID/%{Y}/TAIL/Z", "/ROOT/r1/MID/m2/TAIL/Z", true},
    {:object, "/ROOT/%{X}/MID/%{Y}/TAIL/Z", "/ROOT/r1/MID/m2/TAIL", true},
    {:individual, "/Ping/Pong/%{Who}/Score/Final", "/Ping/Pong/Alice/Score/Final", true},
    {:individual, "/Ping/Pong/%{Who}/Score/Final", "/Ping/Pong/Alice/ScoreFinal", false}
  ]

  defp value_to_check(:individual, value), do: value
  defp value_to_check(:object, value) when is_map(value), do: value |> Map.values() |> Enum.at(0)

  @doc false
  describe "test utilities" do
    test "path_matches_endpoint?/3" do
      for {aggregation, endpoint, path, expected} <- @endpoints_path do
        assert expected == ValueGenerator.path_matches_endpoint?(aggregation, endpoint, path)
      end
    end
  end

  @doc false
  describe "value generator" do
    @describetag :success
    @describetag :ut

    property "generates value" do
      check all value <- ValueGenerator.value() do
        assert %{path: _path, value: _value} = value
      end
    end

    property "generates value based on interface" do
      check all interface <- InterfaceGenerator.interface(),
                value <- ValueGenerator.value(interface: interface) do
        assert %{path: _path, value: _value} = value
      end
    end

    property "generates value must have mapping path matches endpoint" do
      check all %Interface{mappings: mappings, aggregation: aggregation} = interface <-
                  InterfaceGenerator.interface(),
                %{path: path, value: _value} <- ValueGenerator.value(interface: interface) do
        assert Enum.any?(mappings, fn %Mapping{endpoint: endpoint} ->
                 ValueGenerator.path_matches_endpoint?(aggregation, endpoint, path)
               end)
      end
    end

    property "generates value must be valid type" do
      check all %Interface{mappings: mappings, aggregation: aggregation} = interface <-
                  InterfaceGenerator.interface(),
                %{path: path, value: value} <- ValueGenerator.value(interface: interface) do
        value = value_to_check(aggregation, value)

        %Mapping{value_type: value_type} =
          Enum.find(mappings, fn %Mapping{endpoint: endpoint} ->
            ValueGenerator.path_matches_endpoint?(aggregation, endpoint, path)
          end)

        assert ValueType.validate_value(value_type, value)
      end
    end
  end
end
