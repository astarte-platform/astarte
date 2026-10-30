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
  use Astarte.DataUpdaterPlant.Cases.Data, async: true
  use Astarte.DataUpdaterPlant.Cases.Device
  use Astarte.DataUpdaterPlant.Cases.DataUpdater
  use ExUnitProperties
  use Mimic

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Mapping
  alias Astarte.DataAccess.Data
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataUpdaterPlant.DataQueryHelper
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.DataHandler
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.Interface
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.HandshakeState
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.Trigger
  alias Astarte.Secrets
  alias Astarte.Secrets.DataEncryptionKeyCache, as: DEKCache
  alias Astarte.Secrets.EncryptedMessages

  import Astarte.InterfaceUpdateGenerators

  @generated_data_points 100

  setup_all context do
    keyspace = Realm.keyspace_name(context.realm)

    # generate a new DEK to be used in DataHandler internal encryptions during this test suite
    DEKCache.reset_realm_dek(context.realm)
    {:ok, current_dek_entry} = DEKCache.fetch_data_encryption_key(context.realm)

    %{keyspace: keyspace, current_dek: current_dek_entry}
  end

  setup context do
    timestamp = System.system_time(:microsecond) * 10
    start = System.monotonic_time()
    # retrieve shared key to encrypt test messages from device
    shared_key = context.state.shared_secret

    # create dummy payload to be sent by device, specific per interface type
    payload_value =
      case Map.get(context, :interface_aggregation) do
        :individual ->
          "encryptmeplease"

        # only first 2 endpoints are encrypted (look at interfaces setup in Cases.Device)
        :object ->
          %{
            "endpoint0" => "encryptme",
            "endpoint1" => "encryptmetoo",
            "endpoint2" => "plaintextforme"
          }

        _ ->
          nil
      end

    payload_encoded =
      %{"v" => payload_value}
      |> Cyanide.encode!()
      |> EncryptedMessages.encrypt(shared_key)

    %{
      payload: payload_encoded,
      payload_value: payload_value,
      timestamp: timestamp,
      start: start
    }
  end

  describe "encryption with realm DEK of incoming data on encrypted endpoints" do
    @tag interface_aggregation: :individual
    test "is applied for interfaces of type 'properties'", context do
      %{
        state: state,
        keyspace: keyspace,
        device_id: device_id,
        interfaces: interfaces,
        payload: payload,
        payload_value: payload_value,
        timestamp: timestamp,
        start: start,
        current_dek: current_dek
      } = context

      test_interface_name = "test.EncryptedPropertiesInterface"
      interface = Enum.find(interfaces, &(&1.name == test_interface_name))

      encrypted_mapping = Enum.find(interface.mappings, & &1.encrypted)

      endpoint_path = encrypted_mapping.endpoint |> String.replace("%{some_param}", "some_value")

      # message is received by DUP and handled correctly
      assert {:ack, :ok, _, _} =
               DataHandler.handle_data(
                 state,
                 test_interface_name,
                 endpoint_path,
                 payload,
                 timestamp,
                 start
               )

      # querying the data saved in db for this endpoint: assert encrypted property and
      # related DEK got stored, and value when decrypted corresponds to plaintext payload value
      [db_data_entry] =
        DataQueryHelper.query_endpoint_data(
          interface,
          endpoint_path,
          encrypted_mapping.endpoint,
          device_id,
          keyspace,
          :property
        )

      assert %{encryptedblob_value: encrypted_val, encrypted_dek: encrypted_dek} = db_data_entry
      assert is_binary(encrypted_dek)
      # the current DEK is stored in db in its ciphertext version
      assert encrypted_dek == current_dek.ciphertext

      # value can be decrypted with the current DEK
      {:ok, decrypted_val} = Secrets.decrypt_with_dek(encrypted_val, current_dek.plaintext)
      assert decrypted_val |> :erlang.binary_to_term() == payload_value
    end

    @tag interface_aggregation: :individual
    test "is applied for interfaces of type 'individual datastream'", context do
      %{
        state: state,
        keyspace: keyspace,
        device_id: device_id,
        interfaces: interfaces,
        payload: payload,
        payload_value: payload_value,
        timestamp: timestamp,
        start: start,
        current_dek: current_dek
      } = context

      test_interface_name = "test.EncryptedIndividualDatastreamInterface"
      interface = Enum.find(interfaces, &(&1.name == test_interface_name))

      encrypted_mapping = Enum.find(interface.mappings, & &1.encrypted)

      endpoint_path = encrypted_mapping.endpoint |> String.replace("%{some_param}", "some_value")

      assert {:ack, :ok, _, _} =
               DataHandler.handle_data(
                 state,
                 test_interface_name,
                 endpoint_path,
                 payload,
                 timestamp,
                 start
               )

      # querying the data saved in db for this endpoint: assert encrypted individual value and
      # related DEK got stored, and value when decrypted corresponds to plaintext payload value
      [db_data_entry] =
        DataQueryHelper.query_endpoint_data(
          interface,
          endpoint_path,
          encrypted_mapping.endpoint,
          device_id,
          keyspace,
          :individual_datastream
        )

      assert %{encryptedblob_value: encrypted_val, encrypted_dek: encrypted_dek} = db_data_entry
      assert is_binary(encrypted_dek)
      assert encrypted_dek == current_dek.ciphertext

      {:ok, decrypted_val} = Secrets.decrypt_with_dek(encrypted_val, current_dek.plaintext)
      assert decrypted_val |> :erlang.binary_to_term() == payload_value
    end

    @tag interface_aggregation: :object
    test "is applied for interfaces of type 'object datastream'", context do
      %{
        state: state,
        keyspace: keyspace,
        device_id: device_id,
        interfaces: interfaces,
        payload: payload,
        payload_value: payload_value,
        timestamp: timestamp,
        start: start,
        current_dek: current_dek
      } = context

      test_interface_name = "test.EncryptedObjectDatastreamInterface"
      interface = Enum.find(interfaces, &(&1.name == test_interface_name))

      common_endpoint_path =
        interface.mappings |> Enum.at(0) |> Map.get(:endpoint) |> Path.dirname()

      leaf_endpoints = get_interface_endpoints(interface)

      assert {:ack, :ok, _, _} =
               DataHandler.handle_data(
                 state,
                 test_interface_name,
                 common_endpoint_path,
                 payload,
                 timestamp,
                 start
               )

      # querying the data saved in db for this endpoint: assert encrypted object values and
      # related DEK got stored, and values when decrypted correspond to plaintext payload values.
      # Assert only encrypted endpoints got their value actually encrypted in db
      endpoints_db_columns = Enum.map(leaf_endpoints, fn {_, db_column, _} -> db_column end)

      [db_data_entry] =
        DataQueryHelper.query_endpoint_data(
          interface,
          common_endpoint_path,
          endpoints_db_columns,
          device_id,
          keyspace,
          true,
          :object_datastream
        )

      assert %{encrypted_dek: encrypted_dek} = db_data_entry
      assert is_binary(encrypted_dek)
      assert encrypted_dek == current_dek.ciphertext

      decrypted_object = decrypt_object_value(db_data_entry, leaf_endpoints, current_dek)
      assert decrypted_object == payload_value
    end

    test "is not applied when a nil value is sent on property endpoints with allow_unset option",
         context do
      %{
        state: state,
        keyspace: keyspace,
        device_id: device_id,
        interfaces: interfaces,
        payload: payload,
        timestamp: timestamp,
        start: start
      } = context

      test_interface_name = "test.EncryptedPropertiesInterface"
      interface = Enum.find(interfaces, &(&1.name == test_interface_name))

      encrypted_mapping = Enum.find(interface.mappings, & &1.encrypted)

      endpoint_path = encrypted_mapping.endpoint

      # message is received by DUP and handled correctly
      assert {:ack, :ok, _, _} =
               DataHandler.handle_data(
                 state,
                 test_interface_name,
                 endpoint_path,
                 payload,
                 timestamp,
                 start
               )

      # querying the data saved in db for this endpoint: assert property row is missing
      # (no encryption and storing was attempted)
      assert [] =
               DataQueryHelper.query_endpoint_data(
                 interface,
                 endpoint_path,
                 encrypted_mapping.endpoint,
                 device_id,
                 keyspace,
                 :property
               )
    end
  end

  describe "shared key state on encrypted endpoints" do
    @tag interface_aggregation: :individual
    test "is restored as established when the key is loaded from the database", context do
      %{state: state} = context

      shared_secret = state.shared_secret.k
      assert {:established, %{shared_secret: ^shared_secret}} = state.encrypted_endpoints_key

      assert {:ack, :ok, _, _} = handle_encrypted_property(context, state)
    end

    @tag interface_aggregation: :individual
    test "accepts encrypted data right after a handshake completes", context do
      %{state: state} = context

      handshake_started =
        {:handshake_started, %{key_type: :ecdh_p256_hkdf_sha256_aes_256_gcm, init_exchange: nil}}

      {:ok, established} =
        HandshakeState.transition(
          handshake_started,
          {:handshake_completed, state.shared_secret.k}
        )

      state = %{state | encrypted_endpoints_key: established}

      assert {:ack, :ok, _, _} = handle_encrypted_property(context, state)
    end
  end

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

    @tag regression: true
    test "correctly validates object aggregate values for current interface", context do
      %{
        fixed_object_datastream_1: fixed_object_datastream_1,
        fixed_object_datastream_2: fixed_object_datastream_2
      } = context

      timestamp = System.system_time(:microsecond) * 10
      start = System.monotonic_time()

      {:ok, _, state} =
        Interface.maybe_handle_cache_miss(nil, fixed_object_datastream_1.name, context.state)

      {:ok, _, state} =
        Interface.maybe_handle_cache_miss(nil, fixed_object_datastream_2.name, state)

      ctx = gen_context(state, fixed_object_datastream_1) |> Enum.at(0)

      %{
        interface: interface_name,
        path: path,
        payload: payload
      } = ctx

      assert {:ack, :ok, _, _} =
               DataHandler.handle_data(state, interface_name, path, payload, timestamp, start)

      ctx = gen_context(state, fixed_object_datastream_2) |> Enum.at(0)

      %{
        interface: interface_name,
        path: path,
        payload: payload
      } = ctx

      assert {:ack, :ok, _, _} =
               DataHandler.handle_data(state, interface_name, path, payload, timestamp, start)
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

  describe "property previous value retrieved from db" do
    setup %{interfaces: interfaces} do
      device_property_interface =
        Enum.find(interfaces, &(&1.type == :properties and &1.ownership == :device))

      encrypted_device_property_interface =
        Enum.find(interfaces, &(&1.name == "test.EncryptedPropertiesInterface"))

      %{
        interface: device_property_interface,
        encrypted_interface: encrypted_device_property_interface
      }
    end

    test "matches incoming property value when stored non-encrypted", context do
      %{
        state: state,
        interface: device_property_interface,
        timestamp: timestamp,
        start: start
      } = context

      %{
        interface: interface_name,
        path: path,
        payload_value: property_value,
        payload: payload
      } = gen_context(state, device_property_interface) |> Enum.at(0)

      # previous property value retrieved from db matches the incoming value
      expect(Data, :fetch_property, fn _, _, _, _, _ -> {:ok, {property_value, nil}} end)

      expect(Trigger, :execute_post_change_triggers, fn trigger_context ->
        assert trigger_context.value == trigger_context.previous_value
        :ok
      end)

      DataHandler.handle_data(state, interface_name, path, payload, timestamp, start)
    end

    test "is treated as nil when property is unset", context do
      %{
        state: state,
        interface: device_property_interface,
        timestamp: timestamp,
        start: start
      } = context

      %{
        interface: interface_name,
        path: path,
        payload: payload
      } = gen_context(state, device_property_interface) |> Enum.at(0)

      # property was previously unset
      expect(Data, :fetch_property, fn _, _, _, _, _ -> {:error, :property_not_set} end)

      expect(Trigger, :execute_post_change_triggers, fn trigger_context ->
        assert trigger_context.previous_value == nil
        :ok
      end)

      DataHandler.handle_data(state, interface_name, path, payload, timestamp, start)
    end

    test "matches incoming property value when stored encrypted", context do
      %{
        state: state,
        encrypted_interface: device_property_interface,
        timestamp: timestamp,
        start: start,
        current_dek: dek
      } = context

      shared_key = state.shared_secret

      %{
        interface: interface_name,
        path: path,
        payload_value: property_value,
        payload: payload
      } = gen_context(state, device_property_interface) |> Enum.at(0)

      # simulate storage of previous property value encrypted
      {:ok, encrypted_stored_property_value} =
        :erlang.term_to_binary(property_value) |> Secrets.encrypt_with_dek(dek.plaintext)

      # mimic retrieval of encrypted property along with DEK used to encrypt it (wrapped with KEK)
      expect(Data, :fetch_property, fn _, _, _, _, _ ->
        {:ok, {encrypted_stored_property_value, dek.ciphertext}}
      end)

      expect(Trigger, :execute_post_change_triggers, fn trigger_context ->
        assert trigger_context.previous_value == property_value
        assert trigger_context.value == trigger_context.previous_value
        :ok
      end)

      encrypted_payload = payload |> EncryptedMessages.encrypt(shared_key)

      DataHandler.handle_data(state, interface_name, path, encrypted_payload, timestamp, start)
    end

    test "detects change when incoming value differs from stored encrypted value", context do
      %{
        state: state,
        encrypted_interface: device_property_interface,
        timestamp: timestamp,
        start: start,
        current_dek: dek
      } = context

      shared_key = state.shared_secret

      %{
        interface: interface_name,
        path: path,
        payload: payload
      } = gen_context(state, device_property_interface) |> Enum.at(0)

      # mimic storage of previous property value encrypted (but different from the incoming value)
      stored_property_value = :crypto.strong_rand_bytes(16)

      {:ok, encrypted_stored_property_value} =
        :erlang.term_to_binary(stored_property_value) |> Secrets.encrypt_with_dek(dek.plaintext)

      expect(Data, :fetch_property, fn _, _, _, _, _ ->
        {:ok, {encrypted_stored_property_value, dek.ciphertext}}
      end)

      expect(Trigger, :execute_post_change_triggers, fn trigger_context ->
        assert trigger_context.previous_value == stored_property_value
        assert trigger_context.value != trigger_context.previous_value
        :ok
      end)

      encrypted_payload = payload |> EncryptedMessages.encrypt(shared_key)

      DataHandler.handle_data(state, interface_name, path, encrypted_payload, timestamp, start)
    end

    test "is treated as nil when retrieved encrypted but its DEK could not be found", context do
      %{
        state: state,
        encrypted_interface: device_property_interface,
        timestamp: timestamp,
        start: start
      } = context

      shared_key = state.shared_secret

      %{
        interface: interface_name,
        path: path,
        payload: payload
      } = gen_context(state, device_property_interface) |> Enum.at(0)

      # previous property value is set (encrypted), but its DEK is absent
      expect(Data, :fetch_property, fn _, _, _, _, _ ->
        {:ok, {:crypto.strong_rand_bytes(16), nil}}
      end)

      expect(Trigger, :execute_post_change_triggers, fn trigger_context ->
        assert trigger_context.previous_value == nil
        :ok
      end)

      encrypted_payload = payload |> EncryptedMessages.encrypt(shared_key)

      DataHandler.handle_data(state, interface_name, path, encrypted_payload, timestamp, start)
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
        payload_value: update.value,
        payload: payload
      }
    end
  end

  # build a list of tuples {endpoint_x_in_string_format, endpoint_x_in_db_column_format, encrypted?}
  # containing all the leaf endpoints of the mappings for the interface
  defp get_interface_endpoints(interface) do
    Enum.map(
      interface.mappings,
      fn mapping ->
        endpoint_string =
          mapping.endpoint
          |> Path.basename()

        endpoint_db_format =
          endpoint_string
          |> CQLUtils.endpoint_to_db_column_name()
          |> String.to_atom()

        {endpoint_string, endpoint_db_format, Map.get(mapping, :encrypted)}
      end
    )
  end

  # create a plaintext object by reversing DEK encryption (only) on encrypted endpoints
  defp decrypt_object_value(data_entry, endpoints, current_dek) do
    Enum.reduce(endpoints, Map.new(), fn {endpoint_to_string, endpoint_to_db_column, encrypted},
                                         obj_map ->
      decrypted_val =
        case encrypted do
          true ->
            {:ok, decrypted_val} =
              Map.get(data_entry, endpoint_to_db_column)
              |> Secrets.decrypt_with_dek(current_dek.plaintext)

            decrypted_val |> :erlang.binary_to_term()

          _ ->
            Map.get(data_entry, endpoint_to_db_column)
        end

      Map.put(
        obj_map,
        endpoint_to_string,
        decrypted_val
      )
    end)
  end

  defp handle_encrypted_property(context, state) do
    %{interfaces: interfaces, payload: payload, timestamp: timestamp, start: start} = context

    interface = Enum.find(interfaces, &(&1.name == "test.EncryptedPropertiesInterface"))
    encrypted_mapping = Enum.find(interface.mappings, & &1.encrypted)
    endpoint_path = encrypted_mapping.endpoint |> String.replace("%{some_param}", "some_value")

    DataHandler.handle_data(state, interface.name, endpoint_path, payload, timestamp, start)
  end
end
