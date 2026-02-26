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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.CapabilitiesHandlerTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use Astarte.Cases.DataUpdater
  use ExUnitProperties

  alias Astarte.Common.Generators.Timestamp
  alias Astarte.Core.Device.Capabilities
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.CapabilitiesHandler
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries

  describe "handle_capabilities/4" do
    property "updates valid capabilities", %{realm_name: realm_name, state: state, device: device} do
      check all capabilities <- gen_capabilities(),
                timestamp <- Timestamp.timestamp() do
        payload =
          capabilities
          |> Map.from_struct()
          |> Map.new(fn {key, value} -> {to_string(key), to_string(value)} end)
          |> Cyanide.encode!()

        assert {:ack, :ok, updated_state} =
                 CapabilitiesHandler.handle_capabilities(
                   state,
                   payload,
                   timestamp
                 )

        %{capabilities: db_capabilities} = Queries.get_device_status(realm_name, device.device_id)

        assert db_capabilities == capabilities
        assert updated_state.capabilities == capabilities
      end
    end
  end

  defp gen_capabilities do
    gen all purge_properties_format <- member_of([:zlib, :plaintext]) do
      %Capabilities{
        purge_properties_compression_format: purge_properties_format
      }
    end
  end
end
