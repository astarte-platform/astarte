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

defmodule Astarte.Pairing.Agent do
  @moduledoc """
  The Agent context.
  """

  alias Astarte.Core.Device
  alias Astarte.Pairing.Agent.DeviceRegistrationRequest
  alias Astarte.Pairing.Agent.DeviceRegistrationResponse
  alias Astarte.Pairing.Engine

  def register_device(realm, attrs \\ %{}) do
    changeset =
      %DeviceRegistrationRequest{}
      |> DeviceRegistrationRequest.changeset(attrs)

    with {:ok,
          %DeviceRegistrationRequest{hw_id: hw_id, initial_introspection: initial_introspection}} <-
           Ecto.Changeset.apply_action(changeset, :insert),
         initial_introspection =
           Enum.map(initial_introspection, fn {interface_name,
                                               %{"major" => major, "minor" => minor}} ->
             %{
               interface_name: interface_name,
               major_version: major,
               minor_version: minor
             }
           end),
         {:ok, credentials_secret} <-
           Engine.register_device(realm, hw_id, initial_introspection: initial_introspection) do
      {:ok, %DeviceRegistrationResponse{credentials_secret: credentials_secret}}
    end
  end

  def unregister_device(realm, device_id) do
    with {:ok, _} <- Device.decode_device_id(device_id),
         :ok <- Engine.unregister_device(realm, device_id) do
      :ok
    end
  end
end
