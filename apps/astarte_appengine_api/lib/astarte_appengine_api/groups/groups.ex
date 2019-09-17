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

  alias Astarte.AppEngine.API.Groups.Group
  alias Astarte.AppEngine.API.Groups.Queries
  alias Astarte.Core.Device

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

  def list_devices(realm_name, group_name) do
    Queries.list_devices(realm_name, group_name)
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
end
