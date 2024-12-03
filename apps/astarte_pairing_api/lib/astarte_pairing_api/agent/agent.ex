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

defmodule Astarte.Pairing.API.Agent do
  @moduledoc """
  The Agent context.
  """

  alias Astarte.Core.Device
  alias Astarte.Pairing.API.Agent.DeviceRegistrationRequest
  alias Astarte.Pairing.API.Agent.DeviceRegistrationResponse
  alias Astarte.Pairing.API.RPC.Pairing
  alias Astarte.Pairing.API.Utils

  def register_device(realm, attrs \\ %{}) do
    changeset =
      %DeviceRegistrationRequest{}
      |> DeviceRegistrationRequest.changeset(attrs)

    with {:ok,
          %DeviceRegistrationRequest{hw_id: hw_id, initial_introspection: initial_introspection}} <-
           Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, %{credentials_secret: secret}} <-
           Pairing.register_device(realm, hw_id, initial_introspection) do
      {:ok, %DeviceRegistrationResponse{credentials_secret: secret}}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, changeset}

      {:error, %{} = error_map} ->
        {:error, Utils.error_map_into_changeset(changeset, error_map)}

      {:error, _other} ->
        {:error, :rpc_error}
    end
  end

  def unregister_device(realm, device_id) do
    with {:ok, _} <- Device.decode_device_id(device_id),
         :ok <- Pairing.unregister_device(realm, device_id) do
      :ok
    end
  end
end
