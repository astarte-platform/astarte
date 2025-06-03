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

defmodule Astarte.Helpers.Device do
  alias Astarte.AppEngine.API.Device, as: Core
  alias Astarte.AppEngine.API.Device.InterfaceValue
  alias Astarte.AppEngine.API.Repo
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.DataAccess.Realms.Interface
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.RealmManagement.Engine, as: RealmManagement
  alias Astarte.Common.Generators.Timestamp, as: TimestampGenerator
  alias Astarte.Core.Mapping.EndpointsAutomaton
  alias Astarte.DataAccess.Interface, as: InterfaceQueries
  alias Astarte.DataAccess.Mappings, as: MappingsQueries

  import ExUnit.CaptureLog
  import StreamData

  @fallible_value_type [
    :integer,
    :longinteger,
    :string,
    :binaryblob,
    :doublearray,
    :integerarray,
    :booleanarray,
    :longintegerarray,
    :stringarray,
    :binaryblobarray,
    :datetimearray
  ]

  @downsampable_value_type [
    :integer,
    :longinteger,
    :double
  ]

  def insert_interface_cleanly(realm_name, interface) do
    keyspace = Realm.keyspace_name(realm_name)
    interface_db = %Interface{name: interface.name, major_version: interface.major_version}
    interface_json = Jason.encode!(interface)

    Repo.delete(interface_db, prefix: keyspace)

    capture_log(fn -> RealmManagement.install_interface(realm_name, interface_json) end)
  end

  def insert_device_cleanly(realm_name, device, interfaces) do
    keyspace = Realm.keyspace_name(realm_name)
    introspection = interfaces |> Map.new(&{&1.name, &1.major_version})
    introspection_minor = interfaces |> Map.new(&{&1.name, &1.minor_version})
    interfaces_bytes = Map.fetch!(device, :interfaces_bytes)
    interfaces_msgs = Map.fetch!(device, :interfaces_msgs)

    device_db_params = %{
      introspection: introspection,
      introspection_minor: introspection_minor,
      exchanged_bytes_by_interface: interfaces_bytes,
      exchanged_msgs_by_interface: interfaces_msgs
    }

    device_db = struct(Device, Map.merge(device, device_db_params))
    Repo.delete(device_db, prefix: keyspace)
    Repo.insert!(device_db, prefix: keyspace)
  end

  def insert_value(realm_name, device_id, interface_descriptor, mapping_update) do
    insert_values(realm_name, device_id, interface_descriptor, [mapping_update])
  end

  def insert_values(realm_name, device_id, interface_descriptor, mapping_updates) do
    # Run in another process to avoid leaking mox stubs to the test processes
    Task.async(fn ->
      Mox.stub(Astarte.AppEngine.API.RPC.VMQPlugin.ClientMock, :publish, fn _ ->
        {:ok, %{local_matches: 1, remote_matches: 0}}
      end)

      initial_time = TimestampGenerator.timestamp() |> Enum.at(0) |> DateTime.from_unix!()

      update_function =
        case interface_descriptor.aggregation do
          :individual -> &Core.update_individual_interface_values/5
          :object -> &Core.update_object_interface_values/5
        end

      {last_time, _} =
        for mapping_update <- mapping_updates, reduce: {nil, initial_time} do
          {_prev, time} ->
            Mimic.expect(DateTime, :utc_now, fn -> time end)

            update_function.(
              realm_name,
              device_id,
              interface_descriptor,
              mapping_update.path,
              mapping_update.value
            )

            seconds_increment = :rand.uniform(60) + 5
            next = DateTime.add(time, seconds_increment, :second)
            {time, next}
        end

      %{initial_time: initial_time, last_time: last_time}
    end)
    |> Task.await()
  end

  def publish_result_ok(interface, mapping_update, validation_function) do
    local_matches = integer(0..1) |> Enum.at(0)

    remote_matches =
      valid_remote_matches(local_matches, interface.type, mapping_update.reliability)
      |> Enum.at(0)

    Mox.expect(
      Astarte.AppEngine.API.RPC.VMQPlugin.ClientMock,
      :publish,
      fn args ->
        validation_function.(args)

        {:ok, %{local_matches: local_matches, remote_matches: remote_matches}}
      end
    )
  end

  def is_fallible?(interface) do
    interface.mappings
    |> Enum.any?(&(&1.value_type in @fallible_value_type))
  end

  def fallible_value_types do
    @fallible_value_type
  end

  def downsampable?(interface) do
    interface.mappings
    |> Enum.any?(&(&1.value_type in @downsampable_value_type))
  end

  def downsampable_value_types do
    @downsampable_value_type
  end

  def downsampable_paths(_realm_name, interface, registered_paths)
      when interface.aggregation == :object do
    registered_paths[{interface.name, interface.major_version}]
  end

  def downsampable_paths(realm_name, interface, registered_paths)
      when interface.aggregation == :individual do
    {:ok, interface_descriptor} =
      InterfaceQueries.fetch_interface_descriptor(
        realm_name,
        interface.name,
        interface.major_version
      )

    {:ok, mappings_map} =
      MappingsQueries.fetch_interface_mappings_map(realm_name, interface_descriptor.interface_id)

    registered_paths[{interface.name, interface.major_version}]
    |> Enum.filter(fn path ->
      {:ok, endpoint_id} =
        EndpointsAutomaton.resolve_path(path, interface_descriptor.automaton)

      mapping = mappings_map[endpoint_id]
      mapping.value_type in @downsampable_value_type
    end)
  end

  def valid_result?(result, interface, value)
      when interface.aggregation == :individual and is_map(value) do
    similar?(result, value)
  end

  def valid_result?(result, _interface, value) when is_map(result) and is_map(value) do
    Map.intersect(value, result)
    |> Enum.all?(fn {key, result_value} -> similar?(result_value, Map.fetch!(value, key)) end)
  end

  def valid_result?(result, interface, value) when is_list(result) do
    similar?(result, value) or Enum.any?(result, &valid_result?(&1, interface, value))
  end

  def valid_result?(result, _interface, value) do
    similar?(result, value)
  end

  defp similar?(nil = _result, [] = _value), do: true
  defp similar?(%{} = _result, nil = _value), do: true
  defp similar?("" = _result, nil = _value), do: true
  defp similar?(%{"" => nil}, nil), do: true
  defp similar?(%{"" => nil}, []), do: true

  defp similar?(%DateTime{} = datetime, timestamp)
       when is_integer(timestamp),
       do: DateTime.to_unix(datetime) == timestamp

  defp similar?(%{"timestamp" => _, "value" => result}, value), do: similar?(result, value)

  defp similar?(result, value) when is_binary(result) and is_number(value),
    do: result == to_string(value)

  defp similar?(result, value) when is_list(result) and is_list(value) do
    Enum.zip(result, value)
    |> Enum.map(fn {result, value} -> similar?(result, value) end)
    |> Enum.all?()
  end

  defp similar?(result, value) when is_binary(result) and is_struct(value, DateTime),
    do: result == DateTime.to_iso8601(value)

  defp similar?(%{"reception_timestamp" => _, "value" => v}, value), do: similar?(v, value)

  defp similar?(result, value), do: result == value

  def expected_published_value!(value_type, value) do
    {:ok, value} = InterfaceValue.cast_value(value_type, value)
    wrap_value_for_publish(value_type, value)
  end

  def expected_read_value!(value_type, value) do
    {:ok, value} = InterfaceValue.cast_value(value_type, value)
    wrap_value_for_read(value_type, value)
  end

  defp wrap_value_for_publish(:binaryblob, value),
    do: %Cyanide.Binary{subtype: :generic, data: value}

  defp wrap_value_for_publish(:binaryblobarray, value),
    do: Enum.map(value, &wrap_value_for_publish(:binaryblob, &1))

  defp wrap_value_for_publish(:datetime, value), do: DateTime.add(value, 0, :millisecond)

  defp wrap_value_for_publish(:datetimearray, value),
    do: Enum.map(value, &wrap_value_for_publish(:datetime, &1))

  defp wrap_value_for_publish(object_value_types, value) when is_map(object_value_types) do
    Map.new(value, fn {key, value} ->
      type = Map.fetch!(object_value_types, key)
      {key, wrap_value_for_publish(type, value)}
    end)
  end

  defp wrap_value_for_publish(_other, value), do: value

  defp wrap_value_for_read(:binaryblob, value), do: Base.encode64(value)

  defp wrap_value_for_read(:binaryblobarray, value),
    do: Enum.map(value, &wrap_value_for_read(:binaryblob, &1))

  defp wrap_value_for_read(:datetime, value), do: DateTime.add(value, 0, :millisecond)

  defp wrap_value_for_read(:datetimearray, value),
    do: Enum.map(value, &wrap_value_for_read(:datetime, &1))

  defp wrap_value_for_read(object_value_types, value) when is_map(object_value_types) do
    Map.new(value, fn {key, value} ->
      type = Map.fetch!(object_value_types, key)
      {key, wrap_value_for_read(type, value)}
    end)
  end

  defp wrap_value_for_read(_other, value), do: value

  defp valid_remote_matches(_, _, :unreliable), do: integer(0..1)
  defp valid_remote_matches(_, :properties, _), do: integer(0..1)
  defp valid_remote_matches(1, _, _), do: integer(0..1)
  defp valid_remote_matches(_, _, _), do: constant(1)
end
