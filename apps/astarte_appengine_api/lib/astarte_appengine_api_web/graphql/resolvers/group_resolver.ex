#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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
defmodule Astarte.AppEngine.APIWeb.GraphQL.Resolvers.GroupResolver do
  @moduledoc """
  Absinthe resolvers for the device groups.
  """

  alias Astarte.AppEngine.API.Device
  alias Astarte.AppEngine.API.Groups
  alias Astarte.DataAccess.Groups.Group

  def list_groups(_parent, _args, %{context: %{realm_name: realm_name}}) do
    {:ok, Groups.list_groups(realm_name)}
  end

  def get_group(_parent, %{name: name}, %{context: %{realm_name: realm_name}}) do
    Groups.get_group(realm_name, name)
  end

  def list_devices(%Group{group_name: group_name}, args, %{context: %{realm_name: realm_name}}) do
    Groups.list_detailed_devices(realm_name, group_name, Map.put(args, :details, true))
  end

  def get_device(%Group{group_name: group_name}, %{device_id: device_id}, %{
        context: %{realm_name: realm_name}
      }) do
    with :ok <- Groups.ensure_device_in_group(realm_name, group_name, device_id) do
      Device.get_device_status!(realm_name, device_id)
    end
  end
end
