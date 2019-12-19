#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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
