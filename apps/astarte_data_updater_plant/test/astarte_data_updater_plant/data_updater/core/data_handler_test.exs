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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.DataHandlerTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use Astarte.Cases.DataUpdater
  use ExUnitProperties

  alias Astarte.Core.Mapping
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.DataHandler

  import Astarte.InterfaceUpdateGenerators

  @generated_data_points 100

  describe "data_handler/6" do
    test "correctly receives and validates payloads for all defined value types on individual datastream mappings",
         context do
      interface = context.individual_datastream_with_all_endpoint_types

      timestamp = System.system_time(:microsecond) * 10
      start = System.monotonic_time()

      data_points =
        gen_context(context.state, interface) |> Enum.take(@generated_data_points)

      for data_point <- data_points do
        %{
          state: state,
          interface: interface_name,
          path: path,
          payload: payload
        } = data_point

        assert {:ack, :ok, _, _} =
                 DataHandler.handle_data(
                   state,
                   interface_name,
                   path,
                   payload,
                   timestamp,
                   start
                 )
      end
    end

    test "correctly receives and validates payloads for all defined value types on object datastream mappings",
         context do
      interface = context.object_datastream_with_all_endpoint_types

      timestamp = System.system_time(:microsecond) * 10
      start = System.monotonic_time()

      data_points =
        gen_context(context.state, interface) |> Enum.take(@generated_data_points)

      for data_point <- data_points do
        %{
          state: state,
          interface: interface_name,
          path: path,
          payload: payload
        } = data_point

        assert {:ack, :ok, _, _} =
                 DataHandler.handle_data(
                   state,
                   interface_name,
                   path,
                   payload,
                   timestamp,
                   start
                 )
      end
    end
  end

  describe "validate_value_type/2" do
    test "returns ok for valid binaryblob" do
      binary = %Cyanide.Binary{subtype: :generic, data: <<1, 2, 3, 4>>}

      assert :ok = DataHandler.validate_value_type(%Mapping{value_type: :binaryblob}, binary)
    end

    test "returns error for raw binaries in binaryblobs" do
      assert {:error, :unexpected_value_type} =
               DataHandler.validate_value_type(%Mapping{value_type: :binaryblob}, <<1, 2, 3, 4>>)
    end
  end

  defp gen_context(state, interface) do
    gen all update <- valid_complete_mapping_update_for(interface),
            timestamp <- repeatedly(fn -> DateTime.utc_now(:millisecond) end) do
      payload =
        %{
          "v" => update.value,
          "t" => timestamp
        }
        |> Cyanide.encode!()

      %{
        state: state,
        interface: interface.name,
        path: update.path,
        payload: payload
      }
    end
  end
end
