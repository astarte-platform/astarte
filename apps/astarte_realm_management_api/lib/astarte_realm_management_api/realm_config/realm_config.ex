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

defmodule Astarte.RealmManagement.API.RealmConfig do
  alias Astarte.RealmManagement.API.RealmConfig.AuthConfig
  alias Astarte.RealmManagement.API.RPC.AMQPClient

  require Logger

  def get_auth_config(realm) do
    with {:ok, jwt_public_key_pem} <- AMQPClient.get_jwt_public_key_pem(realm) do
      {:ok, %AuthConfig{jwt_public_key_pem: jwt_public_key_pem}}
    end
  end

  def update_auth_config(realm, new_config_params) do
    with %Ecto.Changeset{valid?: true} = changeset <-
           AuthConfig.changeset(%AuthConfig{}, new_config_params),
         %AuthConfig{jwt_public_key_pem: pem} <- Ecto.Changeset.apply_changes(changeset),
         :ok <- AMQPClient.update_jwt_public_key_pem(realm, pem) do
      :ok
    else
      %Ecto.Changeset{valid?: false} = changeset ->
        {:error, %{changeset | action: :update}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
