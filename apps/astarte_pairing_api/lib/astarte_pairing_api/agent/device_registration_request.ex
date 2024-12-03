# Copyright 2017-2019 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

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
    field :initial_introspection, :map, default: %{}
  end

  @doc false
  def changeset(%DeviceRegistrationRequest{} = request, attrs) do
    request
    |> cast(attrs, [:hw_id, :initial_introspection])
    |> validate_required([:hw_id])
    |> validate_hw_id(:hw_id)
    |> validate_change(:initial_introspection, &validate_introspection/2)
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

  defp validate_introspection(field, introspection) when is_map(introspection) do
    Enum.reduce(introspection, [], fn
      {interface_name, %{"major" => major, "minor" => minor}}, acc
      when is_integer(major) and is_integer(minor) ->
        if major < 0 or minor < 0 do
          [{field, "has negative versions in interface #{interface_name}"}]
        else
          acc
        end

      {interface_name, _}, acc ->
        [{field, "has invalid format for interface #{interface_name}"} | acc]
    end)
  end
end
