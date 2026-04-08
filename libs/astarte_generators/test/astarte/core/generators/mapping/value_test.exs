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
  alias Astarte.Core.Generators.Mapping, as: MappingGenerator
  alias Astarte.Core.Generators.Mapping.Value, as: ValueGenerator
  alias Astarte.Core.Generators.Mapping.ValueType, as: ValueTypeGenerator

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

  defp unpack_first(%{type: type, value: value, path: base_path}) do
    postfix = type |> Map.keys() |> Enum.at(0)

    %{
      path: base_path <> "/" <> postfix,
      type: Map.get(type, postfix),
      value: Map.get(value, postfix)
    }
  end

  defp gen_object_type_t, do: map_of(string(:ascii), ValueTypeGenerator.value_type())

  @doc false
  describe "test utilities" do
    @describetag :success
    @describetag :ut

    test "path_matches_endpoint?/3" do
      for {aggregation, endpoint, path, expected} <- @endpoints_path do
        assert expected == ValueGenerator.path_matches_endpoint?(aggregation, endpoint, path)
      end
    end

    property "path_from_endpoint/1" do
      check all endpoint <- MappingGenerator.endpoint(),
                path <- ValueGenerator.path_from_endpoint(endpoint) do
        # I must use :individual to prevent the last part of the endpoint from being truncated.
        assert ValueGenerator.path_matches_endpoint?(:individual, endpoint, path)
      end
    end

    property "type_value_from_path/3 aggregation :individual" do
      check all %Interface{aggregation: aggregation} = interface <-
                  InterfaceGenerator.interface(aggregation: :individual),
                %{path: path, type: type_1, value: value_1} = package <-
                  ValueGenerator.value(interface: interface),
                max_runs: 10 do
        %{type: type_2, value: value_2} =
          ValueGenerator.type_value_from_path(aggregation, path, package)

        assert type_1 == type_2 and value_1 == value_2
      end
    end

    property "type_value_from_path/3 aggregation :object" do
      check all %Interface{aggregation: aggregation} = interface <-
                  InterfaceGenerator.interface(aggregation: :object),
                package <-
                  ValueGenerator.value(interface: interface)
                  |> filter(fn %{type: type, value: value} ->
                    map_size(type) > 0 and map_size(value) > 0
                  end),
                %{path: path, type: type_1, value: value_1} = unpack_first(package),
                max_runs: 10 do
        %{type: type_2, value: value_2} =
          ValueGenerator.type_value_from_path(aggregation, path, package)

        assert type_1 == type_2 and value_1 == value_2
      end
    end

    @tag :failure
    property "type_value_from_path/3 not found" do
      check all %Interface{aggregation: aggregation} = interface <-
                  InterfaceGenerator.interface(),
                %{path: path} = package <- ValueGenerator.value(interface: interface),
                max_runs: 10 do
        not_exists_path = path <> "/not_exist"
        assert :error = ValueGenerator.type_value_from_path(aggregation, not_exists_path, package)
      end
    end
  end

  @doc false
  describe "object_value_from_type/1" do
    @describetag :success
    @describetag :ut

    property "using gen" do
      check all value <- gen_object_type_t() |> ValueGenerator.object_value_from_type() do
        for {postfix, value} <- value do
          assert is_binary(postfix) and not is_nil(value)
        end
      end
    end

    property "using struct" do
      check all type <- gen_object_type_t(),
                value <- ValueGenerator.object_value_from_type(type) do
        for {postfix, type} <- type do
          assert ValueType.validate_value(type, Map.fetch!(value, postfix))
        end
      end
    end
  end

  @doc false
  describe "value generator" do
    @describetag :success
    @describetag :ut

    property "generates value" do
      check all value <- ValueGenerator.value() do
        assert %{path: _path, value: _value, type: _type} = value
      end
    end

    property "generates value based on interface" do
      check all interface <- InterfaceGenerator.interface(),
                value <- ValueGenerator.value(interface: interface) do
        assert %{path: _path, value: _value, type: _type} = value
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

    property "generates :individual value must be valid type" do
      check all %Interface{mappings: mappings} = interface <-
                  InterfaceGenerator.interface(aggregation: :individual),
                %{path: path} = package <-
                  ValueGenerator.value(interface: interface) do
        %Mapping{value_type: value_type} =
          Enum.find(mappings, fn %Mapping{endpoint: endpoint} ->
            ValueGenerator.path_matches_endpoint?(:individual, endpoint, path)
          end)

        %{type: generated_type, value: generated_value} =
          ValueGenerator.type_value_from_path(:individual, path, package)

        assert generated_type == value_type and
                 ValueType.validate_value(value_type, generated_value)
      end
    end

    property "generates :object value must be valid type" do
      check all %Interface{mappings: mappings} = interface <-
                  InterfaceGenerator.interface(aggregation: :object),
                package <-
                  ValueGenerator.value(interface: interface)
                  |> filter(fn %{type: type, value: value} ->
                    map_size(type) > 0 and map_size(value) > 0
                  end),
                %{path: path, type: field_type, value: field_value} = unpack_first(package) do
        field_postfix = path |> String.split("/") |> List.last()

        %Mapping{value_type: value_type} =
          Enum.find(mappings, fn %Mapping{endpoint: endpoint} ->
            ValueGenerator.path_matches_endpoint?(:object, endpoint, package.path) and
              endpoint |> String.split("/") |> List.last() == field_postfix
          end)

        %{type: generated_type, value: generated_value} =
          ValueGenerator.type_value_from_path(:object, path, package)

        assert generated_type == value_type and
                 generated_type == field_type and
                 generated_value == field_value and
                 ValueType.validate_value(value_type, generated_value)
      end
    end
  end
end
