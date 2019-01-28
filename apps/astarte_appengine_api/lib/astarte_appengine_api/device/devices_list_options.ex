#
# This file is part of Astarte.
#
# Copyright 2018 Ispirata Srl
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

defmodule Astarte.AppEngine.API.Device.DevicesListOptions do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.AppEngine.API.Device.DevicesListOptions

  @primary_key false
  embedded_schema do
    field :from_token, :integer, default: nil
    field :limit, :integer, default: 1000
    field :details, :boolean, default: false
  end

  @doc false
  def changeset(%DevicesListOptions{} = devices_list_request, attrs) do
    cast_attrs = [
      :from_token,
      :limit,
      :details
    ]

    devices_list_request
    |> cast(attrs, cast_attrs)
    |> validate_number(:limit, greater_than: 0)
  end
end
