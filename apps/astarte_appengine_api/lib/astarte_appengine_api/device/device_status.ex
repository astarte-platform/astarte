#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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
  use Ecto.Schema
  import Ecto.Changeset

  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Device.InterfaceInfo
  alias Astarte.AppEngine.API.Device.Queries
  alias Astarte.Core.Device
  alias Astarte.DataAccess.Realms.Device, as: DatabaseDevice
  alias Astarte.DataAccess.Repo

  require Logger

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

  @spec from_device(DatabaseDevice, String.t()) :: %__MODULE__{}
  def from_device(device, realm_name) do
    {introspection_major, introspection_minor} = clean_device_introspection(device)

    %{
      device_id: device_id,
      aliases: aliases,
      connected: connected,
      last_connection: last_connection,
      last_disconnection: last_disconnection,
      first_registration: first_registration,
      first_credentials_request: first_credentials_request,
      last_credentials_request_ip: last_credentials_request_ip,
      last_seen_ip: last_seen_ip,
      attributes: attributes,
      total_received_msgs: total_received_msgs,
      total_received_bytes: total_received_bytes,
      exchanged_msgs_by_interface: exchanged_msgs_by_interface,
      exchanged_bytes_by_interface: exchanged_bytes_by_interface,
      groups: groups,
      old_introspection: old_introspection,
      inhibit_credentials_request: credentials_inhibited
    } = device

    introspection =
      Map.merge(introspection_major, introspection_minor, fn interface, major, minor ->
        interface_key = {interface, major}
        messages = exchanged_msgs_by_interface |> Map.get(interface_key, 0)
        bytes = exchanged_bytes_by_interface |> Map.get(interface_key, 0)

        %InterfaceInfo{
          major: major,
          minor: minor,
          exchanged_msgs: messages,
          exchanged_bytes: bytes
        }
      end)

    previous_interfaces =
      for {{interface, major}, minor} <- old_introspection do
        interface_key = {interface, major}
        msgs = exchanged_msgs_by_interface |> Map.get(interface_key, 0)
        bytes = exchanged_bytes_by_interface |> Map.get(interface_key, 0)

        %InterfaceInfo{
          name: interface,
          major: major,
          minor: minor,
          exchanged_msgs: msgs,
          exchanged_bytes: bytes
        }
      end

    groups =
      case groups do
        nil -> []
        groups -> groups |> Map.keys()
      end

    deletion_in_progress? =
      Queries.deletion_in_progress(realm_name)
      |> Repo.fetch(device_id)
      |> case do
        {:ok, _} -> true
        {:error, _reason} -> false
      end

    device_id = Device.encode_device_id(device_id)
    connected = connected || false
    last_credentials_request_ip = ip_string(last_credentials_request_ip)
    last_seen_ip = ip_string(last_seen_ip)
    last_connection = truncate_datetime(last_connection)
    last_disconnection = truncate_datetime(last_disconnection)
    first_registration = truncate_datetime(first_registration)
    first_credentials_request = truncate_datetime(first_credentials_request)

    %DeviceStatus{
      id: device_id,
      aliases: aliases,
      introspection: introspection,
      connected: connected,
      deletion_in_progress: deletion_in_progress?,
      last_connection: last_connection,
      last_disconnection: last_disconnection,
      first_registration: first_registration,
      first_credentials_request: first_credentials_request,
      last_credentials_request_ip: last_credentials_request_ip,
      last_seen_ip: last_seen_ip,
      attributes: attributes,
      credentials_inhibited: credentials_inhibited,
      total_received_msgs: total_received_msgs,
      total_received_bytes: total_received_bytes,
      previous_interfaces: previous_interfaces,
      groups: groups
    }
  end

  defp clean_device_introspection(device) do
    introspection_major = device.introspection || %{}
    introspection_minor = device.introspection_minor || %{}

    major_keys = introspection_major |> Map.keys() |> MapSet.new()
    minor_keys = introspection_minor |> Map.keys() |> MapSet.new()

    corrupted = MapSet.symmetric_difference(major_keys, minor_keys) |> MapSet.to_list()

    for interface <- corrupted do
      device_id = Device.encode_device_id(device.device_id)

      Logger.error("Introspection has either major or minor, but not both. Corrupted entry?",
        interface: interface,
        device_id: device_id
      )
    end

    introspection_major = introspection_major |> Map.drop(corrupted)
    introspection_minor = introspection_minor |> Map.drop(corrupted)

    {introspection_major, introspection_minor}
  end

  def from_db_row(row) when is_map(row) do
    %{
      "device_id" => device_id,
      "aliases" => aliases,
      "introspection" => introspection_major,
      "introspection_minor" => introspection_minor,
      "connected" => connected,
      "last_connection" => last_connection,
      "last_disconnection" => last_disconnection,
      "first_registration" => first_registration,
      "first_credentials_request" => first_credentials_request,
      "last_credentials_request_ip" => last_credentials_request_ip,
      "last_seen_ip" => last_seen_ip,
      "attributes" => attributes,
      "inhibit_credentials_request" => credentials_inhibited,
      "total_received_msgs" => total_received_msgs,
      "total_received_bytes" => total_received_bytes,
      "groups" => groups_map,
      "exchanged_msgs_by_interface" => exchanged_msgs_by_interface,
      "exchanged_bytes_by_interface" => exchanged_bytes_by_interface,
      "old_introspection" => old_introspection
    } = row

    introspection =
      Map.merge(introspection_major || %{}, introspection_minor || %{}, fn
        interface_name, major, minor ->
          exchanged_msgs =
            (exchanged_msgs_by_interface || %{})
            |> Map.get({interface_name, major}, 0)

          exchanged_bytes =
            (exchanged_bytes_by_interface || %{})
            |> Map.get({interface_name, major}, 0)

          %InterfaceInfo{
            major: major,
            minor: minor,
            exchanged_msgs: exchanged_msgs,
            exchanged_bytes: exchanged_bytes
          }
      end)

    previous_interfaces =
      Enum.map(old_introspection || %{}, fn {{interface_name, major}, minor} ->
        exchanged_msgs =
          (exchanged_msgs_by_interface || %{})
          |> Map.get({interface_name, major}, 0)

        exchanged_bytes =
          (exchanged_bytes_by_interface || %{})
          |> Map.get({interface_name, major}, 0)

        %InterfaceInfo{
          name: interface_name,
          major: major,
          minor: minor,
          exchanged_msgs: exchanged_msgs,
          exchanged_bytes: exchanged_bytes
        }
      end)

    # groups_map could be nil, default to empty map
    groups = Map.keys(groups_map || %{})

    %DeviceStatus{
      id: Device.encode_device_id(device_id),
      aliases: aliases || %{},
      introspection: introspection,
      connected: connected,
      last_connection: last_connection,
      last_disconnection: last_disconnection,
      first_registration: first_registration,
      first_credentials_request: first_credentials_request,
      last_credentials_request_ip: ip_string(last_credentials_request_ip),
      last_seen_ip: ip_string(last_seen_ip),
      attributes: attributes || %{},
      credentials_inhibited: credentials_inhibited,
      total_received_msgs: total_received_msgs,
      total_received_bytes: total_received_bytes,
      previous_interfaces: previous_interfaces,
      groups: groups
    }
  end

  defp ip_string(nil) do
    nil
  end

  defp ip_string(ip) when is_tuple(ip) do
    ip
    |> :inet_parse.ntoa()
    |> to_string
  end

  defp truncate_datetime(nil), do: nil
  defp truncate_datetime(datetime), do: datetime |> DateTime.truncate(:millisecond)
end
