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

defmodule Astarte.AppEngine.API.Device.DeviceV2Test do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.InterfaceValues

  import Astarte.Helpers.Device
  import Astarte.InterfaceUpdateGenerators

  describe "update_interface_value" do
    property "returns the given value for valid parameters", context do
      %{realm_name: realm_name, interfaces: interfaces, device: device} = context
      valid_interfaces_for_update = interfaces |> Enum.filter(&(&1.ownership == :server))

      check all interface_to_update <- member_of(valid_interfaces_for_update),
                mapping_update <- valid_mapping_update_for(interface_to_update) do
        update_value = mapping_update.value
        path_tokens = String.split(mapping_update.path, "/")
        expected_token = [realm_name, device.encoded_id, interface_to_update.name | path_tokens]

        expected_published_value =
          expected_published_value!(mapping_update.value_type, update_value)

        expected_qos = expected_qos_for!(mapping_update)

        expected_read_value = expected_read_value!(mapping_update.value_type, update_value)
        read_path = path_tokens |> Enum.drop(1)

        publish_result_ok(interface_to_update, mapping_update, fn args ->
          assert %{payload: payload, topic_tokens: topic_tokens, qos: qos} = args
          assert topic_tokens == expected_token
          assert qos == expected_qos
          assert {:ok, %{"v" => ^expected_published_value}} = Cyanide.decode(payload)
        end)

        assert {:ok, %InterfaceValues{data: ^update_value}} =
                 Device.update_interface_values(
                   realm_name,
                   device.encoded_id,
                   interface_to_update.name,
                   mapping_update.path,
                   update_value,
                   []
                 )

        {:ok, %InterfaceValues{data: result}} =
          Device.get_interface_values!(
            realm_name,
            device.encoded_id,
            interface_to_update.name,
            %{}
          )

        result = get_in(result, read_path)
        assert valid_result?(result, interface_to_update, expected_read_value)
      end
    end
  end

  property "fails for invalid device id", args do
    %{realm_name: realm_name, interfaces: interfaces, device: device} = args
    valid_interfaces_for_update = interfaces |> Enum.filter(&(&1.ownership == :server))
    extended_id = device.encoded_id <> "ab"

    check all interface <- member_of(valid_interfaces_for_update),
              mapping_update <- valid_mapping_update_for(interface) do
      assert {:error, _} =
               Device.update_interface_values(
                 realm_name,
                 extended_id,
                 interface.name,
                 mapping_update.path,
                 mapping_update.value,
                 []
               )
    end
  end

  property "fails for device owned interfaces", args do
    %{realm_name: realm_name, interfaces: interfaces, device: device} = args
    device_owned_interfaces = interfaces |> Enum.filter(&(&1.ownership == :device))

    check all interface <- member_of(device_owned_interfaces),
              mapping_update <- valid_mapping_update_for(interface) do
      assert {:error, :cannot_write_to_device_owned} ==
               Device.update_interface_values(
                 realm_name,
                 device.encoded_id,
                 interface.name,
                 mapping_update.path,
                 mapping_update.value,
                 []
               )
    end
  end

  property "fails for invalid types", args do
    %{realm_name: realm_name, interfaces: interfaces, device: device} = args
    valid_interfaces_for_update = interfaces |> Enum.filter(&(&1.ownership == :server))

    check all interface <- member_of(valid_interfaces_for_update),
              mapping_update <- valid_nonempty_mapping_update_for(interface),
              value <- invalid_type(mapping_update.value_type) do
      assert {:error, :unexpected_value_type, [{:expected, _}]} =
               Device.update_interface_values(
                 realm_name,
                 device.encoded_id,
                 interface.name,
                 mapping_update.path,
                 value,
                 []
               )
    end
  end

  property "fails for invalid values", args do
    %{realm_name: realm_name, interfaces: interfaces, device: device} = args

    valid_interfaces_for_update =
      Enum.filter(interfaces, fn interface ->
        fallible?(interface) and interface.ownership == :server
      end)

    check all interface <- member_of(valid_interfaces_for_update),
              mapping_update <- valid_fallible_mapping_update_for(interface),
              value <- invalid_value(mapping_update.value_type) do
      result =
        Device.update_interface_values(
          realm_name,
          device.encoded_id,
          interface.name,
          mapping_update.path,
          value,
          []
        )

      case result do
        {:error, _} -> :ok
        {:error, :unexpected_value_type, _} -> :ok
        _ -> flunk("Wrong return type: #{inspect(result)}")
      end
    end
  end

  defp expected_qos_for!(mapping_update) do
    case mapping_update.reliability do
      :unreliable -> 0
      :guaranteed -> 1
      :unique -> 2
    end
  end
end
