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

defmodule Astarte.PairingWeb.GraphQL.Resolvers.AgentResolverTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.Pairing.Agent
  alias Astarte.Pairing.Agent.DeviceRegistrationResponse
  alias Astarte.PairingWeb.GraphQL.Resolvers.AgentResolver

  @context %{context: %{realm_name: "testrealm"}}
  @hw_id "2TBn-jNESuuHamE2Zo1anA"

  defp registered do
    {:ok, %DeviceRegistrationResponse{credentials_secret: "secret"}}
  end

  describe "register_device/3" do
    test "turns the introspection entries into the REST API's introspection map" do
      expect(Agent, :register_device, fn "testrealm", params ->
        assert params == %{
                 hw_id: @hw_id,
                 initial_introspection: %{
                   "org.example.Values" => %{"major" => 1, "minor" => 2},
                   "org.example.Commands" => %{"major" => 0, "minor" => 3}
                 }
               }

        registered()
      end)

      args = %{
        hw_id: @hw_id,
        initial_introspection: [
          %{interface: "org.example.Values", major_version: 1, minor_version: 2},
          %{interface: "org.example.Commands", major_version: 0, minor_version: 3}
        ]
      }

      assert AgentResolver.register_device(nil, args, @context) ==
               {:ok, %{credentials_secret: "secret"}}
    end

    test "registers an empty introspection when none or null is given" do
      for args <- [%{hw_id: @hw_id}, %{hw_id: @hw_id, initial_introspection: nil}] do
        expect(Agent, :register_device, fn "testrealm", params ->
          assert params == %{hw_id: @hw_id, initial_introspection: %{}}
          registered()
        end)

        assert {:ok, _} = AgentResolver.register_device(nil, args, @context)
      end
    end

    test "reports why the registration failed" do
      expect(Agent, :register_device, fn _realm, _params ->
        {:error, :device_already_registered}
      end)

      assert AgentResolver.register_device(nil, %{hw_id: @hw_id}, @context) ==
               {:error, :device_already_registered}
    end
  end
end
