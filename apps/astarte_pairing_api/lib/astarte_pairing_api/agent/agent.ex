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
# Copyright (C) 2017 Ispirata Srl
#

defmodule Astarte.Pairing.API.Agent do
  @moduledoc """
  The Agent context.
  """

  alias Astarte.Pairing.API.Agent.APIKey
  alias Astarte.Pairing.API.Agent.APIKeyRequest
  alias Astarte.Pairing.API.RPC.AMQPClient
  alias Astarte.Pairing.API.Utils

  def generate_api_key(attrs \\ %{}) do
    changeset =
      %APIKeyRequest{}
      |> APIKeyRequest.changeset(attrs)

    if changeset.valid? do
      %APIKeyRequest{hw_id: hw_id, realm: realm} = Ecto.Changeset.apply_changes(changeset)

      case AMQPClient.generate_api_key(realm, hw_id) do
        {:ok, api_key} ->
          {:ok, %APIKey{api_key: api_key}}

        {:error, %{} = error_map} ->
          {:error, Utils.error_map_into_changeset(changeset, error_map)}

        _other ->
          {:error, :rpc_error}
      end
    else
      {:error, %{changeset | action: :create}}
    end
  end
end
