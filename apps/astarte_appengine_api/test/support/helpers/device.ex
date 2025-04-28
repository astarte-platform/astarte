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
  alias Astarte.AppEngine.API.Device.InterfaceValue
  alias Astarte.AppEngine.API.Repo
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.DataAccess.Realms.Interface
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.RealmManagement.Engine, as: RealmManagement
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

  def publish_result_ok(interface, mapping_update, validation_function) do
    local_matches = integer(0..1) |> Enum.at(0)

    remote_matches =
      valid_remote_matches(local_matches, interface.type, mapping_update.reliability)
      |> Enum.at(0)

    Mox.expect(Astarte.AppEngine.API.RPC.VMQPlugin.ClientMock, :publish, fn args ->
      validation_function.(args)

      {:ok, %{local_matches: local_matches, remote_matches: remote_matches}}
    end)
  end

  def is_fallible?(interface) do
    interface.mappings
    |> Enum.any?(&(&1.value_type in @fallible_value_type))
  end

  def fallible_value_types do
    @fallible_value_type
  end

  def valid_result?(result, interface, value)
      when interface.aggregation == :individual do
    similar?(result, value)
  end

  def valid_result?(result, _interface, value) when is_map(result) do
    Map.intersect(value, result)
    |> Enum.all?(fn {key, result_value} -> similar?(result_value, Map.fetch!(value, key)) end)
  end

  def valid_result?(result, interface, value) when is_list(result) do
    Enum.any?(result, &valid_result?(&1, interface, value))
  end

  defp similar?(nil = _result, [] = _value), do: true

  defp similar?(result, value) when is_binary(result) and is_number(value),
    do: result == to_string(value)

  defp similar?(result, value) when is_list(result) and is_list(value) do
    Enum.zip(result, value)
    |> Enum.map(fn {result, value} -> similar?(result, value) end)
    |> Enum.all?()
  end

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
