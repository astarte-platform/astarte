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

defmodule Astarte.AppEngine.API.Device.DeviceV2Test do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties

  import Astarte.Generators.InterfaceUpdate
  import Astarte.Helpers.Device

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.InterfaceValues
  alias Astarte.Core.Generators.Device, as: DeviceGenerator
  alias Astarte.Core.Interface, as: CoreInterface
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.DataAccess.Interface, as: InterfaceQueries

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

  describe "realm maximum storage retention and mapping database_retention_ttl interaction" do
    setup %{realm_name: realm_name, astarte_instance_id: astarte_instance_id} do
      interface = retention_interface!()
      insert_interface_cleanly(realm_name, interface)

      device = DeviceGenerator.device(interfaces: [interface]) |> Enum.at(0)
      insert_device_cleanly(realm_name, device, [interface])

      {:ok, descriptor} =
        InterfaceQueries.fetch_interface_descriptor(
          realm_name,
          interface.name,
          interface.major_version
        )

      Mox.stub(Astarte.AppEngine.API.RPC.VMQPlugin.ClientMock, :publish, fn _ ->
        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      on_exit(fn ->
        setup_database_access(astarte_instance_id)
        unset_datastream_maximum_storage_retention!(realm_name)
      end)

      %{device: device, interface: interface, descriptor: descriptor}
    end

    # The realm maximum is not enforced when the interface is installed, it is applied
    # here, on every write. These cover the four combinations of the two settings.

    test "realm maximum caps a higher database_retention_ttl", ctx do
      set_datastream_maximum_storage_retention!(ctx.realm_name, 600)

      assert_stored_ttl(ctx, "/longTtl", 600)
    end

    test "database_retention_ttl wins when lower than the realm maximum", ctx do
      set_datastream_maximum_storage_retention!(ctx.realm_name, 600)

      assert_stored_ttl(ctx, "/shortTtl", 120)
    end

    test "database_retention_ttl applies when no realm maximum is set", ctx do
      assert_stored_ttl(ctx, "/longTtl", 3600)
    end

    test "no_ttl mappings still expire after the realm maximum", ctx do
      set_datastream_maximum_storage_retention!(ctx.realm_name, 600)

      assert_stored_ttl(ctx, "/noTtl", 600)
    end

    test "no_ttl mappings never expire when no realm maximum is set", ctx do
      assert_stored_ttl(ctx, "/noTtl", nil)
    end
  end

  defp retention_interface! do
    mapping = fn endpoint, retention ->
      Map.merge(%{"endpoint" => endpoint, "type" => "integer"}, retention)
    end

    params = %{
      "interface_name" => "org.astarte-platform.test.ServerRetention",
      "version_major" => 1,
      "version_minor" => 0,
      "type" => "datastream",
      "ownership" => "server",
      "aggregation" => "individual",
      "mappings" => [
        mapping.("/longTtl", %{
          "database_retention_policy" => "use_ttl",
          "database_retention_ttl" => 3600
        }),
        mapping.("/shortTtl", %{
          "database_retention_policy" => "use_ttl",
          "database_retention_ttl" => 120
        }),
        mapping.("/noTtl", %{"database_retention_policy" => "no_ttl"})
      ]
    }

    %CoreInterface{}
    |> CoreInterface.changeset(params)
    |> Ecto.Changeset.apply_action!(:insert)
  end

  defp assert_stored_ttl(ctx, path, expected_ttl) do
    %{realm_name: realm_name, device: device, interface: interface, descriptor: descriptor} = ctx

    assert {:ok, _} =
             Device.update_interface_values(
               realm_name,
               device.encoded_id,
               interface.name,
               String.trim_leading(path, "/"),
               10,
               []
             )

    {:ok, endpoint_id} = EndpointsAutomaton.resolve_path(path, descriptor.automaton)

    ttl =
      fetch_individual_datastream_ttl!(
        realm_name,
        device.device_id,
        descriptor.interface_id,
        endpoint_id,
        path
      )

    case expected_ttl do
      nil -> assert ttl == nil
      # The TTL counts down from the moment of the write
      expected_ttl -> assert ttl in (expected_ttl - 5)..expected_ttl
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
