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
#

defmodule Astarte.AppEngine.API.Rooms.WatchRequest do
  use Ecto.Schema

  import Ecto.Changeset
  alias Astarte.AppEngine.API.Rooms.WatchRequest
  alias Astarte.Core.Device
  alias Astarte.Core.Triggers.SimpleTriggerConfig

  @primary_key false
  embedded_schema do
    field :name, :string
    field :device_id, :string
    embeds_one :simple_trigger, SimpleTriggerConfig
  end

  @required [:name, :device_id]

  @doc false
  def changeset(%WatchRequest{} = data, params \\ %{}) do
    data
    |> cast(params, @required)
    |> validate_required(@required)
    |> validate_change(:device_id, &validate_device_id/2)
    |> cast_embed(:simple_trigger, required: true)
  end

  defp validate_device_id(field, device_id) do
    case Device.decode_device_id(device_id) do
      {:ok, _decoded_id} ->
        []

      {:error, :invalid_device_id} ->
        [{field, "is not a valid device id"}]

      {:error, :extended_id_not_allowed} ->
        [{field, "is too long, device id must be 128 bits"}]
    end
  end
end
