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

defmodule Astarte.AppEngine.API.Device.DeviceReadingV2Test do
  use Astarte.Cases.Data, async: true

  use Astarte.Cases.Device
  use ExUnitProperties

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.InterfaceValues
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  import Astarte.Helpers.Device
  import Astarte.InterfaceUpdateGenerators

  describe "get_interface_value" do
    setup context do
      %{astarte_instance_id: astarte_instance_id, realm_name: realm_name} = context

      on_exit(fn ->
        setup_database_access(astarte_instance_id)
        clean_device_saved_data(realm_name)
      end)
    end

    property "returns the value (from root) ", context do
      %{
        realm_name: realm_name,
        interfaces: interfaces,
        device: device
      } = context

      valid_interfaces_for_update = interfaces |> Enum.filter(&(&1.ownership == :server))

      check all(
              interface_to_update <- member_of(valid_interfaces_for_update),
              mapping_update <- valid_mapping_update_for(interface_to_update)
            ) do
        %{
          interface_to_update: interface_to_update,
          read_path: read_path,
          expected_read_value: expected_read_value
        } = populate_interface(realm_name, device, interface_to_update, mapping_update)

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

    property "returns the value from interface path ", context do
      %{
        realm_name: realm_name,
        interfaces: interfaces,
        device: device
      } = context

      valid_interfaces_for_update = interfaces |> Enum.filter(&(&1.ownership == :server))

      check all interface_to_update <- member_of(valid_interfaces_for_update),
                mapping_update <- valid_mapping_update_for(interface_to_update) do
        %{
          interface_to_update: interface_to_update,
          expected_read_value: expected_read_value,
          mapping_update: mapping_update
        } = populate_interface(realm_name, device, interface_to_update, mapping_update)

        {:ok, %InterfaceValues{data: result}} =
          Device.get_interface_values!(
            realm_name,
            device.encoded_id,
            interface_to_update.name,
            mapping_update.path,
            %{limit: 1}
          )

        assert valid_result?(result, interface_to_update, expected_read_value)
      end
    end
  end

  describe "get_interface_value null and limit" do
    setup context do
      %{astarte_instance_id: astarte_instance_id, realm_name: realm_name} = context

      on_exit(fn ->
        setup_database_access(astarte_instance_id)
        clean_device_saved_data(realm_name)
      end)
    end

    property "returns nil when the value is not present", context do
      %{
        realm_name: realm_name,
        interfaces: interfaces,
        device: device
      } = context

      valid_interfaces_for_update = interfaces |> Enum.filter(&(&1.ownership == :server))

      check all interface_to_update <- member_of(valid_interfaces_for_update) do
        {:ok, %InterfaceValues{data: result}} =
          Device.get_interface_values!(
            realm_name,
            device.encoded_id,
            interface_to_update.name,
            %{}
          )

        assert valid_result?(result, interface_to_update, nil)
      end
    end

    property "returns data using a limit", context do
      %{
        realm_name: realm_name,
        interfaces: interfaces,
        device: device
      } = context

      valid_interfaces_for_update = interfaces |> Enum.filter(&(&1.ownership == :server))

      check all(
              interface_to_update <- member_of(valid_interfaces_for_update),
              mapping_update <- valid_mapping_update_for(interface_to_update),
              limit_n <- integer(1..400)
            ) do
        %{
          interface_to_update: interface_to_update,
          expected_read_value: expected_read_value,
          mapping_update: mapping_update
        } =
          for _ <- 1..limit_n do
            populate_interface(realm_name, device, interface_to_update, mapping_update)
          end
          |> Enum.at(0)

        {:ok, %InterfaceValues{data: result}} =
          Device.get_interface_values!(
            realm_name,
            device.encoded_id,
            interface_to_update.name,
            mapping_update.path,
            %{limit: limit_n}
          )

        assert valid_result?(result, interface_to_update, expected_read_value)
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

  defp clean_device_saved_data(realm_name) do
    Repo.query!("TRUNCATE #{Realm.keyspace_name(realm_name)}.individual_properties")
    Repo.query!("TRUNCATE #{Realm.keyspace_name(realm_name)}.individual_datastreams")
  end

  defp populate_interface(realm_name, device, interface_to_update, mapping_update) do
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

    {:ok, _} =
      Device.update_interface_values(
        realm_name,
        device.encoded_id,
        interface_to_update.name,
        mapping_update.path,
        update_value,
        []
      )

    %{
      interface_to_update: interface_to_update,
      read_path: read_path,
      expected_read_value: expected_read_value,
      mapping_update: mapping_update
    }
  end
end
