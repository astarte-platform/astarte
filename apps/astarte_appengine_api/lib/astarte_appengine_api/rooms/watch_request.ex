#
# This file is part of Astarte.
#
# Astarte is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Astarte is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Astarte.  If not, see <http://www.gnu.org/licenses/>.
#
# Copyright (C) 2018 Ispirata Srl
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
    |> validate_device_id(:device_id)
    |> cast_embed(:simple_trigger, required: true)
  end

  defp validate_device_id(%Ecto.Changeset{} = changeset, field) do
    with {:ok, device_id} <- fetch_change(changeset, field),
         {:ok, _decoded_id} <- Device.decode_device_id(device_id) do
      changeset
    else
      :error ->
        # No device id found, already an error changeset
        changeset

      {:error, :invalid_device_id} ->
        # device_device_id failed
        add_error(changeset, field, "is not a valid device id")

      {:error, :extended_id_not_allowed} ->
        add_error(changeset, field, "is too long, device id must be 128 bits")
    end
  end
end
