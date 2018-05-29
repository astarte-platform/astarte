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
# Copyright (C) 2017-2018 Ispirata Srl
#

defmodule Astarte.Pairing.API.Agent.DeviceRegistrationRequest do
  use Ecto.Schema
  import Ecto.Changeset
  alias Astarte.Core.Device
  alias Astarte.Pairing.API.Agent.DeviceRegistrationRequest

  @primary_key false
  embedded_schema do
    field :hw_id, :string
  end

  @doc false
  def changeset(%DeviceRegistrationRequest{} = request, attrs) do
    request
    |> cast(attrs, [:hw_id])
    |> validate_required([:hw_id])
    |> validate_hw_id(:hw_id)
  end

  defp validate_hw_id(changeset, field) do
    with {:ok, hw_id} <- fetch_change(changeset, field),
         {:ok, _decoded_id} <- Device.decode_device_id(hw_id, allow_extended_id: true) do
      changeset
    else
      # No hw_id, already handled
      :error ->
        changeset

      _ ->
        add_error(changeset, field, "is not a valid base64 encoded 128 bits id")
    end
  end
end
