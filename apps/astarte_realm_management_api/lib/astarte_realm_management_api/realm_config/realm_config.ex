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

defmodule Astarte.RealmManagement.API.RealmConfig do
  alias Astarte.RealmManagement.API.RealmConfig.AuthConfig
  alias Astarte.RealmManagement.API.RPC.RealmManagement

  def get_auth_config(realm) do
    with {:ok, jwt_public_key_pem} <- RealmManagement.get_jwt_public_key_pem(realm) do
      {:ok, %AuthConfig{jwt_public_key_pem: jwt_public_key_pem}}
    end
  end

  def get_device_registration_limit(realm) do
    RealmManagement.get_device_registration_limit(realm)
  end

  def update_auth_config(realm, new_config_params) do
    with %Ecto.Changeset{valid?: true} = changeset <-
           AuthConfig.changeset(%AuthConfig{}, new_config_params),
         %AuthConfig{jwt_public_key_pem: pem} <- Ecto.Changeset.apply_changes(changeset),
         :ok <- RealmManagement.update_jwt_public_key_pem(realm, pem) do
      :ok
    else
      %Ecto.Changeset{valid?: false} = changeset ->
        {:error, %{changeset | action: :update}}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
