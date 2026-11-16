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
defmodule Astarte.AppEngine.APIWeb.GraphQL.Types.GroupTypes do
  @moduledoc """
  GraphQL types for the device groups.
  """

  use Absinthe.Schema.Notation

  alias Astarte.DataAccess.Groups.Group

  @desc "A device group of the realm"
  object :device_group do
    @desc "The name of the group"
    field :name, non_null(:string) do
      resolve fn %Group{group_name: group_name}, _args, _resolution -> {:ok, group_name} end
    end
  end
end
