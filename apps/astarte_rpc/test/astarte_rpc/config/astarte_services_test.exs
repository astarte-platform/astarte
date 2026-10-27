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

defmodule Astarte.RPC.Config.AstarteServicesTest do
  use ExUnit.Case, async: true

  alias Astarte.RPC.Config.AstarteServices

  describe "cast/1" do
    test "returns ok with valid single service" do
      assert {:ok, [:astarte_data_updater_plant]} ==
               AstarteServices.cast([:astarte_data_updater_plant])
    end

    test "returns ok with multiple valid services" do
      services = [:astarte_pairing, :astarte_realm_management]
      assert {:ok, result} = AstarteServices.cast(services)
      assert MapSet.equal?(MapSet.new(result), MapSet.new(services))
    end

    test "returns ok with all valid services" do
      services = [
        :astarte_data_updater_plant,
        :astarte_pairing,
        :astarte_realm_management,
        :astarte_vmq_plugin
      ]

      assert {:ok, result} = AstarteServices.cast(services)
      assert MapSet.equal?(MapSet.new(result), MapSet.new(services))
    end

    test "returns error with invalid service" do
      assert :error == AstarteServices.cast([:invalid_service])
    end

    test "returns error with mix of valid and invalid services" do
      assert :error ==
               AstarteServices.cast([
                 :astarte_pairing,
                 :invalid_service
               ])
    end

    test "returns ok with empty list" do
      assert {:ok, []} == AstarteServices.cast([])
    end
  end
end
