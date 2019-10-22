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
  use Ecto.Schema
  import Ecto.Changeset

  alias Astarte.AppEngine.API.Device.DeviceStatus
  alias Astarte.AppEngine.API.Device.InterfaceVersion
  alias Astarte.Core.Device

  @primary_key {:id, :binary_id, autogenerate: false}
  embedded_schema do
    field :aliases, {:map, :string}
    field :introspection, :map
    field :connected, :boolean
    field :last_connection, :utc_datetime
    field :last_disconnection, :utc_datetime
    field :first_registration, :utc_datetime
    field :first_credentials_request, :utc_datetime
    field :last_credentials_request_ip
    field :last_seen_ip
    field :total_received_msgs, :integer
    field :total_received_bytes, :integer
    field :groups, {:array, :string}
  end

  @doc false
  def changeset(%DeviceStatus{} = device_status, params \\ %{}) do
    device_status
    |> cast(params, [:aliases])
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
      "total_received_msgs" => total_received_msgs,
      "total_received_bytes" => total_received_bytes,
      "groups" => groups_map
    } = row

    introspection =
      Map.merge(introspection_major || %{}, introspection_minor || %{}, fn _key, major, minor ->
        %InterfaceVersion{major: major, minor: minor}
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
      total_received_msgs: total_received_msgs,
      total_received_bytes: total_received_bytes,
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
end
