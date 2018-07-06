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

defmodule Astarte.Pairing.API.Agent do
  @moduledoc """
  The Agent context.
  """

  alias Astarte.Pairing.API.Agent.DeviceRegistrationRequest
  alias Astarte.Pairing.API.Agent.DeviceRegistrationResponse
  alias Astarte.Pairing.API.RPC.Pairing
  alias Astarte.Pairing.API.Utils

  def register_device(realm, attrs \\ %{}) do
    changeset =
      %DeviceRegistrationRequest{}
      |> DeviceRegistrationRequest.changeset(attrs)

    with {:ok, %DeviceRegistrationRequest{hw_id: hw_id}} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, %{credentials_secret: secret}} <- Pairing.register_device(realm, hw_id) do
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
end
