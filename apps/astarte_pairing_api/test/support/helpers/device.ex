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
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.DataAccess.Realms.Interface
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.RealmManagement.Engine, as: RealmManagement

  import ExUnit.CaptureLog

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

  def fallible_value_types do
    @fallible_value_type
  end
end
