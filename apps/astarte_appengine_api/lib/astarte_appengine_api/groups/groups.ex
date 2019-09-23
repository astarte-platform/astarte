#
# This file is part of Astarte.
#
# Copyright 2019 Ispirata Srl
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

defmodule Astarte.AppEngine.API.Groups do
  @moduledoc """
  The groups context
  """

  alias Astarte.AppEngine.API.Device.DevicesListOptions
  alias Astarte.AppEngine.API.Groups.Group
  alias Astarte.AppEngine.API.Groups.Queries
  alias Astarte.Core.Device

  @default_list_limit 1000

  def create_group(realm_name, params) do
    changeset = Group.changeset(%Group{}, params)

    Queries.create_group(realm_name, changeset)
  end

  def list_groups(realm_name) do
    Queries.list_groups(realm_name)
  end

  def get_group(realm_name, group_name) do
    Queries.get_group(realm_name, group_name)
  end

  def list_detailed_devices(realm_name, group_name, params \\ %{}) do
    changeset = DevicesListOptions.changeset(%DevicesListOptions{}, params)

    with {:ok, options} <- Ecto.Changeset.apply_action(changeset, :insert) do
      opts =
        options
        |> Map.from_struct()
        |> Enum.to_list()

      Queries.list_devices(realm_name, group_name, opts)
    end
  end

  def list_devices(realm_name, group_name, params \\ %{}) do
    # We don't use DevicesListOptions.changeset here since from_token
    # is a string in this case
    types = %{from_token: :string, details: :boolean, limit: :integer}

    changeset =
      {%DevicesListOptions{}, types}
      |> Ecto.Changeset.cast(params, Map.keys(types))
      |> Ecto.Changeset.validate_change(:from_token, fn :from_token, token ->
        is_uuid? =
          token
          |> to_charlist()
          |> :uuid.string_to_uuid()
          |> :uuid.is_v1()

        if is_uuid? do
          []
        else
          [from_token: "is invalid"]
        end
      end)

    with {:ok, options} <- Ecto.Changeset.apply_action(changeset, :insert) do
      opts =
        options
        |> Map.from_struct()
        |> Map.put_new(:limit, @default_list_limit)
        |> Enum.to_list()

      Queries.list_devices(realm_name, group_name, opts)
    end
  end

  def add_device(realm_name, group_name, params) do
    types = %{device_id: :string}

    changeset =
      {%{}, types}
      |> Ecto.Changeset.cast(params, [:device_id])
      |> Ecto.Changeset.validate_change(:device_id, fn :device_id, device_id ->
        case Device.decode_device_id(device_id) do
          {:ok, _decoded} -> []
          {:error, _reason} -> [device_id: "is not a valid device id"]
        end
      end)

    Queries.add_device(realm_name, group_name, changeset)
  end

  def remove_device(realm_name, group_name, device_id) do
    Queries.remove_device(realm_name, group_name, device_id)
  end

  def check_device_in_group(realm_name, group_name, device_id) do
    Queries.check_device_in_group(realm_name, group_name, device_id)
  end
end
