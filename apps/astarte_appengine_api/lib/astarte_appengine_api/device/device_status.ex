#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.AppEngine.API.Device.DeviceStatus do
  @moduledoc false
  use Ecto.Schema
  import Ecto.Changeset

  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Device.InterfaceInfo
  alias Astarte.Core.Device

  @primary_key {:id, :binary_id, autogenerate: false}
  embedded_schema do
    field :aliases, {:map, :string}
    field :introspection, :map
    field :connected, :boolean
    field :last_connection, :utc_datetime_usec
    field :last_disconnection, :utc_datetime_usec
    field :first_registration, :utc_datetime_usec
    field :first_credentials_request, :utc_datetime_usec
    field :last_credentials_request_ip
    field :last_seen_ip
    field :attributes, {:map, :string}
    field :credentials_inhibited, :boolean
    field :total_received_msgs, :integer
    field :total_received_bytes, :integer
    field :previous_interfaces, {:array, :map}
    field :groups, {:array, :string}
    field :deletion_in_progress, :boolean, default: false
  end

  @doc false
  def changeset(%DeviceStatus{} = device_status, params \\ %{}) do
    device_status
    |> cast(params, [:aliases, :credentials_inhibited, :attributes])
  end

  def from_db_row(row) when is_map(row) do
    %{
      device_id: device_id,
      groups: groups_map,
      exchanged_msgs_by_interface: exchanged_msgs_by_interface,
      exchanged_bytes_by_interface: exchanged_bytes_by_interface
    } = row

    %DeviceStatus{
      id: Device.encode_device_id(device_id),
      aliases: row.aliases || %{},
      introspection:
        build_introspection(row, exchanged_msgs_by_interface, exchanged_bytes_by_interface),
      connected: row.connected,
      last_connection: truncate_datetime(row.last_connection),
      last_disconnection: truncate_datetime(row.last_disconnection),
      first_registration: truncate_datetime(row.first_registration),
      first_credentials_request: truncate_datetime(row.first_credentials_request),
      last_credentials_request_ip: ip_string(row.last_credentials_request_ip),
      last_seen_ip: ip_string(row.last_seen_ip),
      attributes: row.attributes || %{},
      credentials_inhibited: row.inhibit_credentials_request,
      total_received_msgs: row.total_received_msgs,
      total_received_bytes: row.total_received_bytes,
      previous_interfaces:
        build_previous_interfaces(
          row.old_introspection,
          exchanged_msgs_by_interface,
          exchanged_bytes_by_interface
        ),
      groups: Map.keys(groups_map || %{})
    }
  end

  # Helper for actual introspection
  defp build_introspection(row, msgs_map, bytes_map) do
    Map.merge(row.introspection || %{}, row.introspection_minor || %{}, fn
      interface_name, major, minor ->
        build_interface_info(interface_name, major, minor, msgs_map, bytes_map)
    end)
  end

  defp build_previous_interfaces(old_introspection, msgs_map, bytes_map) do
    Enum.map(old_introspection || %{}, fn {{name, major}, minor} ->
      build_interface_info(name, major, minor, msgs_map, bytes_map, include_name: true)
    end)
  end

  defp build_interface_info(name, major, minor, msgs_map, bytes_map, opts \\ []) do
    msgs = Map.get(msgs_map || %{}, {name, major}, 0)
    bytes = Map.get(bytes_map || %{}, {name, major}, 0)

    info = %InterfaceInfo{
      major: major,
      minor: minor,
      exchanged_msgs: msgs,
      exchanged_bytes: bytes
    }

    if Keyword.get(opts, :include_name, false), do: %{info | name: name}, else: info
  end

  defp truncate_datetime(nil), do: nil
  defp truncate_datetime(datetime), do: datetime |> DateTime.truncate(:millisecond)

  defp ip_string(nil) do
    nil
  end

  defp ip_string(ip) when is_tuple(ip) do
    ip
    |> :inet_parse.ntoa()
    |> to_string
  end
end
