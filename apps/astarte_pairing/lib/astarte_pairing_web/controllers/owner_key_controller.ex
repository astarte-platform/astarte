#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.PairingWeb.OwnerKeyController do
  use Astarte.PairingWeb, :controller

  alias Astarte.Secrets
  alias Astarte.Secrets.OwnerKeyInitialization
  alias Astarte.Secrets.OwnerKeyInitializationOptions

  require Logger

  action_fallback Astarte.PairingWeb.FallbackController

  def create_or_upload_key(
        conn,
        %{
          "data" => data,
          "realm_name" => realm_name
        }
      ) do
    # TODO handle userID when available
    create_or_upload_changeset =
      OwnerKeyInitializationOptions.changeset(%OwnerKeyInitializationOptions{}, data)

    with {:ok, create_or_upload_changeset} <-
           Ecto.Changeset.apply_action(create_or_upload_changeset, :insert),
         {:ok, public_key} <-
           OwnerKeyInitialization.create_or_upload(create_or_upload_changeset, realm_name) do
      send_resp(conn, 200, public_key)
    end
  end

  @supported_key_algorithms [:es256, :es384, :rs256, :rs384]
  def list_keys(
        conn,
        %{
          "realm_name" => realm_name
        }
      ) do
    keys = Secrets.Core.get_keys_from_algorithm(realm_name, @supported_key_algorithms)
    send_resp(conn, 200, Jason.encode!(keys))
  end
end
