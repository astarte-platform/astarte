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
  use ExUnitProperties

  alias Astarte.Common.Generators.Timestamp
  alias Astarte.Core.Device.Capabilities
  alias Astarte.DataUpdaterPlant.DataUpdater
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.CapabilitiesHandler
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries
  alias Astarte.DataUpdaterPlant.MessageTracker

  import Astarte.Helpers.DataUpdater

  setup_all %{realm_name: realm_name, device: device} do
    %{message_tracker: message_tracker} = setup_data_updater(realm_name, device.encoded_id)
    state = DataUpdater.dump_state(realm_name, device.encoded_id)

    %{state: state, message_tracker: message_tracker}
  end

  describe "handle_capabilities/4" do
    property "updates valid capabilities", context do
      %{realm_name: realm_name, state: state, device: device, message_tracker: message_tracker} =
        context

      check all capabilities <- gen_capabilities(),
                timestamp <- Timestamp.timestamp(),
                tracking_id <- repeatedly(&gen_tracking_id/0) do
        {message_id, delivery_tag} = tracking_id
        MessageTracker.track_delivery(message_tracker, message_id, delivery_tag)

        payload =
          capabilities
          |> Map.from_struct()
          |> Map.new(fn {key, value} -> {to_string(key), to_string(value)} end)
          |> Cyanide.encode!()

        updated_state =
          CapabilitiesHandler.handle_capabilities(
            state,
            payload,
            message_id,
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
