#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

  alias Astarte.Core.Interface
  alias Astarte.Core.Mapping

  alias Astarte.Core.Generators.Interface, as: InterfaceGenerator
  alias Astarte.Core.Generators.Mapping, as: MappingGenerator

  @moduletag :core
  @moduletag :interface

  @endpoint_cases [
    {["/AbCde", "/AbCde/QwEr", "/XyZ"], ["/AbCde", "/XyZ"]},
    {["/shop/Prd45", "/shop/Prd45/Details"], ["/shop/Prd45"]},
    {["/alpha/Beta", "/alpha/Beta/Gamma", "/alpha/Delta"], ["/alpha/Beta", "/alpha/Delta"]},
    {["/%{RootB}/Xy", "/%{RootA}", "/%{RootA}/Xy", "/Abc"], ["/%{RootB}/Xy"]},
    {["/%{RootB}", "/%{RootB}/Seg1", "/%{RootB}/Seg1/Seg2"], ["/%{RootB}"]},
    {["/api/%{CA}", "/api/%{CA}/status", "/api/%{VA}/status"], ["/api/%{CA}"]},
    {["/api/%{V_1}", "/api/%{V_1}/ping", "/api/%{V_2}"], ["/api/%{V_1}"]},
    {["/api/%{V_1}/detail", "/%{mask}/detail", "/api/%{V_2}"], ["/api/%{V_1}/detail"]},
    {["/Ux9/Za2", "/Ux9/Za2/Rt7"], ["/Ux9/Za2"]},
    {["/foo/%{idA}", "/foo/%{idB}/bar"], ["/foo/%{idA}"]},
    {["/foo/%{Ab1}", "/foo/%{Ab1}/X", "/bar/Baz"], ["/foo/%{Ab1}", "/bar/Baz"]},
    {["/mmNn/ooPP", "/mmNn/ooPP/qqRR"], ["/mmNn/ooPP"]},
    {["/docs/%{Slug_1}", "/docs/%{Slug_1}/v1", "/docs/%{Slug_2}"], ["/docs/%{Slug_1}"]},
    {["/AA/BB", "/AA/BB/CC", "/DD"], ["/AA/BB", "/DD"]},
    {["/AA/BB/CC", "/AA/BB"], ["/AA/BB/CC"]},
    {["/xY/Za", "/xY/Za/Q1", "/xY/Zb"], ["/xY/Za", "/xY/Zb"]},
    {["/p1q2/RS", "/p1q2/RS/TT/UU"], ["/p1q2/RS"]},
    {["/user/%{U_123}", "/user/%{U_123}/orders", "/user/%{U_456}"], ["/user/%{U_123}"]},
    {["/calc/%{ModeA}/run", "/calc/%{ModeB}/run"], ["/calc/%{ModeA}/run"]},
    {["/calc/%{ModeC}/run/now", "/calc/%{ModeC}/run"], ["/calc/%{ModeC}/run/now"]},
    {["/A1b2C3", "/A1b2C3/D4e5"], ["/A1b2C3"]},
    {["/AABB", "/AABBCC"], ["/AABB", "/AABBCC"]},
    {["/srv/%{EnvX}/cfg", "/srv/%{EnvX}/cfg/edit"], ["/srv/%{EnvX}/cfg"]},
    {["/srv/%{Env_1}/cfg", "/srv/%{Env_2}/cfg"], ["/srv/%{Env_1}/cfg"]},
    {["/%{ROOT_X}", "/%{ROOT_Y}", "/%{ROOT_Y}/x"], ["/%{ROOT_X}"]},
    {["/root/%{Id1}/x", "/root/%{Id2}/x/y"], ["/root/%{Id1}/x"]},
    {["/root/%{Abc}/x/y", "/root/%{Abc}/x"], ["/root/%{Abc}/x/y"]},
    {["/kLm/Nop", "/kLm/Nop/Qrs", "/kLm/Tuv"], ["/kLm/Nop", "/kLm/Tuv"]},
    {["/data/%{KeyA}/val", "/data/%{KeyB}/val"], ["/data/%{KeyA}/val"]},
    {["/data/%{KeyA}/val", "/data/%{KeyA}/val/x"], ["/data/%{KeyA}/val"]},
    {["/zZz/%{Pid}/q", "/zZz/%{Pid}/q/r"], ["/zZz/%{Pid}/q"]},
    {["/zZz/%{Pid1}/q", "/zZz/%{Pid2}/w"], ["/zZz/%{Pid1}/q", "/zZz/%{Pid2}/w"]},
    {["/Mix/Aa", "/Mix/Aa/Bb", "/Mix/Cc"], ["/Mix/Aa", "/Mix/Cc"]},
    {["/auth/Login", "/auth/Login/Step2"], ["/auth/Login"]},
    {["/auth/%{FlowA}/step/next", "/auth/%{FlowA}/step"], ["/auth/%{FlowA}/step/next"]},
    {["/auth/%{FlowA}/step", "/auth/%{FlowB}"], ["/auth/%{FlowA}/step"]},
    {["/r1/r2/r3", "/r1/r2"], ["/r1/r2/r3"]},
    {["/r1/%{VarA}", "/r1/%{VarA}/x", "/r2"], ["/r1/%{VarA}", "/r2"]},
    {["/A_/B_", "/A_/B_/C_"], ["/A_/B_"]},
    {["/A_/B_/C_", "/A_/B_/C_/D_"], ["/A_/B_/C_"]},
    {["/node/%{N1}/leaf/%{L2}", "/node/%{N1}/leaf"], ["/node/%{N1}/leaf/%{L2}"]},
    {["/node/%{N1}/leaf/%{L2}", "/node/%{N2}/leaf/%{L3}"], ["/node/%{N1}/leaf/%{L2}"]},
    {["/Sx/Tx", "/Sx/Tx/Ux", "/Sx/Vx"], ["/Sx/Tx", "/Sx/Vx"]},
    {["/G1/H2", "/G1/H2/I3/J4"], ["/G1/H2"]},
    {["/lib/%{Pkg}/v", "/lib/%{Pkg}/v/1"], ["/lib/%{Pkg}/v"]},
    {["/lib/%{PkgA}/v", "/lib/%{PkgB}/v"], ["/lib/%{PkgA}/v"]},
    {["/cat/%{C1}/dog/%{D2}", "/cat/%{C1}/dog/%{D2}/x"], ["/cat/%{C1}/dog/%{D2}"]},
    {["/alpha/%{A1}/beta", "/alpha/%{A1}/beta/gamma"], ["/alpha/%{A1}/beta"]},
    {["/alpha/%{A1}/beta", "/alpha/%{A2}"], ["/alpha/%{A1}/beta"]},
    {["/xLong/SegName", "/xLong/SegName/Next"], ["/xLong/SegName"]},
    {["/Ping", "/Ping/Pong", "/Pang"], ["/Ping", "/Pang"]}
  ]

  @doc false
  describe "interface utilities" do
    test "validate endpoints in :individual" do
      for {endpoints, results} <- @endpoint_cases do
        mappings =
          for endpoint <- endpoints do
            %Mapping{endpoint: endpoint}
          end

        uniq_mappings = InterfaceGenerator.uniq_endpoints(mappings)

        uniq_endpoints =
          for %Mapping{endpoint: endpoint} <- uniq_mappings do
            endpoint
          end

        assert MapSet.new(results) == MapSet.new(uniq_endpoints)
      end
    end

    property "endpoint_by_aggregation/2 returns the expected endpoint for :individual aggregation" do
      check all endpoint <- MappingGenerator.endpoint() do
        expected_endpoint = endpoint

        assert expected_endpoint ==
                 InterfaceGenerator.endpoint_by_aggregation(:individual, endpoint)
      end
    end

    property "endpoint_by_aggregation/2 returns the expected endpoint for :object aggregation" do
      check all endpoint <- MappingGenerator.endpoint() do
        expected_endpoint = endpoint |> String.split("/") |> Enum.drop(-1) |> Enum.join("/")
        assert expected_endpoint == InterfaceGenerator.endpoint_by_aggregation(:object, endpoint)
      end
    end
  end

  @doc false
  describe "interface generator" do
    @describetag :success
    @describetag :ut

    property "validate interface using Changeset and to_change (gen)" do
      gen_interface_changes = InterfaceGenerator.interface() |> InterfaceGenerator.to_changes()

      check all changes <- gen_interface_changes,
                changeset = Interface.changeset(%Interface{}, changes) do
        assert changeset.valid?, "Invalid interface: #{inspect(changeset.errors)}"
      end
    end

    property "validate interface using Changeset and to_change (struct)" do
      check all interface <- InterfaceGenerator.interface(),
                changes <- InterfaceGenerator.to_changes(interface),
                changeset = Interface.changeset(%Interface{}, changes) do
        assert changeset.valid?, "Invalid interface: #{inspect(changeset.errors)}"
      end
    end

    property "validate endpoints in aggregation :object must be the same" do
      check all %Interface{mappings: mappings} <-
                  InterfaceGenerator.interface(aggregation: :object),
                endpoints =
                  mappings
                  |> Enum.map(fn %Mapping{endpoint: endpoint} -> endpoint end)
                  |> Enum.map(&Regex.replace(~r"/[^/]+$", &1, "")) do
        assert 1 == endpoints |> Enum.uniq() |> length()
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

      check all changes <- gen_interface_changes,
                changeset = Interface.changeset(%Interface{}, changes) do
        assert changeset.valid?, "Invalid interface: #{inspect(changeset.errors)}"
      end
    end

    @tag issue: 1072
    property "validate database retention opts in interface aggregate mappings are consistent" do
      check all interface <- InterfaceGenerator.interface(), max_runs: 100 do
        %Mapping{
          database_retention_policy: reference_database_retention_policy,
          database_retention_ttl: reference_database_retention_ttl
        } = Enum.at(interface.mappings, 0)

        assert Enum.all?(interface.mappings, fn
                 %Mapping{
                   database_retention_policy: mapping_database_retention_policy,
                   database_retention_ttl: mapping_database_retention_ttl
                 } ->
                   mapping_database_retention_policy == reference_database_retention_policy and
                     mapping_database_retention_ttl == reference_database_retention_ttl
               end)
      end
    end
  end

  describe "to_changes/1" do
    @describetag :success
    @describetag :ut
    property "allows the resulting map to be json encoded" do
      check all interface <- InterfaceGenerator.interface(),
                changes <- InterfaceGenerator.to_changes(interface) do
        assert {:ok, _json} = Jason.encode(changes)
      end
    end
  end
end
