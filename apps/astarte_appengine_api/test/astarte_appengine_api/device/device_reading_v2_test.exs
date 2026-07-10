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

defmodule Astarte.AppEngine.API.Device.DeviceReadingV2Test do
  use ExUnitProperties
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device

  import Astarte.Helpers.Device

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Device.InterfaceValues
  alias Astarte.AppEngine.API.Device.Queries, as: AppEngineDeviceQueries

  alias Astarte.Core.Device, as: CoreDevice
  alias Astarte.Core.InterfaceDescriptor

  alias Astarte.DataAccess.Device, as: DeviceQueries
  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  alias Astarte.Generators.InterfaceUpdate, as: InterfaceUpdateGenerator

  alias Astarte.Secrets.EncryptedMessages

  alias COSE.Keys.Symmetric

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

      check all interface_to_update <- member_of(valid_interfaces_for_update),
                mapping_update <-
                  InterfaceUpdateGenerator.valid_mapping_update_for(interface_to_update) do
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
                mapping_update <-
                  InterfaceUpdateGenerator.valid_mapping_update_for(interface_to_update) do
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

    property "returns the value for encrypted interfaces", context do
      %{
        realm_name: realm_name,
        interfaces: interfaces,
        device: device
      } = context

      shared_secret = %Symmetric{k: :crypto.strong_rand_bytes(32), alg: :aes_256_gcm}
      {:ok, device_id} = CoreDevice.decode_device_id(device.encoded_id)

      :ok = AppEngineDeviceQueries.save_shared_secret(realm_name, device_id, shared_secret)

      encrypted_server_interfaces =
        interfaces
        |> Enum.filter(fn interface ->
          interface.ownership == :device and
            Enum.any?(interface.mappings, & &1.encrypted)
        end)

      Mimic.stub(Astarte.Secrets.Core, :realm_kek_namespace_tokens, fn _realm_name ->
        ["astarte_encrypted_messages_kek", "default_instance", realm_name]
      end)

      Mimic.stub(Astarte.Secrets, :generate_dek, fn _type, _namespace ->
        {:ok, %{plaintext: :binary.copy(<<1>>, 32), ciphertext: :binary.copy(<<1>>, 32)}}
      end)

      Mimic.stub(Astarte.Secrets, :fetch_realm_kek, fn _ ->
        {:ok,
         %{
           name: "fake-kek",
           namespace: "fake-namespace",
           alg: :aes256_gcm
         }}
      end)

      Mimic.stub(Astarte.Secrets, :unwrap_dek, fn _k, _ct, _ns ->
        {:ok, :binary.copy(<<1>>, 32)}
      end)

      check all interface_to_update <- member_of(encrypted_server_interfaces),
                mapping_update <-
                  InterfaceUpdateGenerator.valid_mapping_update_for(interface_to_update) do
        if mapping_update.value_type != %{} do
          %{
            interface_to_update: interface_to_update,
            expected_read_value: expected_read_value,
            mapping_update: mapping_update
          } =
            populate_interface(
              realm_name,
              device,
              interface_to_update,
              mapping_update,
              shared_secret
            )

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

      check all interface_to_update <- member_of(valid_interfaces_for_update),
                mapping_update <-
                  InterfaceUpdateGenerator.valid_mapping_update_for(interface_to_update),
                limit_n <- integer(1..400) do
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

  defp populate_interface(
         realm_name,
         device,
         interface_to_update,
         mapping_update,
         shared_key \\ nil
       ) do
    update_value = mapping_update.value
    path_tokens = String.split(mapping_update.path, "/")
    expected_token = [realm_name, device.encoded_id, interface_to_update.name | path_tokens]
    encrypted_path? = encrypted_mapping_path?(interface_to_update, mapping_update.path)

    expected_published_value =
      expected_published_value!(mapping_update.value_type, update_value)

    expected_qos = expected_qos_for!(mapping_update)

    expected_read_value = expected_read_value!(mapping_update.value_type, update_value)

    read_path = path_tokens |> Enum.drop(1)

    publish_result_ok(interface_to_update, mapping_update, fn args ->
      assert %{payload: payload, topic_tokens: topic_tokens, qos: qos} = args
      assert topic_tokens == expected_token
      assert qos == expected_qos

      assert {:ok, %{"v" => published_value}} = Cyanide.decode(payload)

      if encrypted_path? do
        assert decrypt_value(published_value, shared_key) == expected_published_value
      else
        assert published_value == expected_published_value
      end
    end)

    with {:ok, device_id} <- CoreDevice.decode_device_id(device.encoded_id),
         {:ok, major_version} <-
           DeviceQueries.interface_version(realm_name, device_id, interface_to_update.name),
         {:ok, interface_row} <-
           InterfaceQueries.retrieve_interface_row(
             realm_name,
             interface_to_update.name,
             major_version
           ),
         {:ok, interface_descriptor} <- InterfaceDescriptor.from_db_result(interface_row),
         path <- "/" <> mapping_update.path do
      if interface_descriptor.aggregation == :individual do
        Device.update_individual_interface_values(
          realm_name,
          device_id,
          interface_descriptor,
          path,
          update_value
        )
      else
        Device.update_object_interface_values(
          realm_name,
          device_id,
          interface_descriptor,
          path,
          update_value
        )
      end
    end

    %{
      interface_to_update: interface_to_update,
      read_path: read_path,
      expected_read_value: expected_read_value,
      mapping_update: mapping_update
    }
  end

  defp encrypted_mapping_path?(interface_to_update, path) do
    normalized_path = normalize_path(path)

    Enum.any?(interface_to_update.mappings, fn mapping ->
      normalized_endpoint = normalize_path(mapping.endpoint)

      mapping.encrypted and
        (normalized_endpoint == normalized_path or
           String.starts_with?(normalized_endpoint, normalized_path <> "/"))
    end)
  end

  defp normalize_path(path) do
    "/" <> String.trim(path, "/")
  end

  defp decrypt_value(encrypted_value, shared_secret) do
    case EncryptedMessages.decrypt(
           encrypted_value,
           shared_secret.k,
           shared_secret.alg
         ) do
      {:ok, decrypted_value} ->
        case Cyanide.decode(decrypted_value) do
          {:ok, %{"v" => value}} ->
            value

          _ ->
            :erlang.binary_to_term(decrypted_value)
        end

      {:error, reason} ->
        flunk("Unable to decrypt published value: #{inspect(reason)}")
    end
  end
end
