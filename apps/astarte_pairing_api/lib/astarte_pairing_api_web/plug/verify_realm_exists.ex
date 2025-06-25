#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.APIWeb.Plug.VerifyRealmExists do
  @behaviour Plug

  import Plug.Conn
  import Phoenix.Controller

  alias Astarte.Pairing.API.Queries

  require Logger

  def init(opts) do
    opts
  end

  def call(conn, _opts) do
    realm_name = conn.path_params["realm_name"]

    case Queries.is_realm_existing(realm_name) do
      {:ok, true} ->
        Logger.metadata(realm: realm_name)

        conn

      {:ok, false} ->
        Logger.warning("Realm #{realm_name} does not exist.",
          tag: "realm_not_found",
          realm: realm_name
        )

        conn
        |> put_status(:forbidden)
        |> put_view(Astarte.Pairing.APIWeb.ErrorView)
        |> render(:"403")
        |> halt()

      {:error, reason} ->
        Logger.error("Error checking if realm exists: #{inspect(reason)}.",
          tag: "realm_check_error",
          realm: realm_name
        )

        conn
        |> put_status(:service_unavailable)
        |> put_view(Astarte.Pairing.APIWeb.ErrorView)
        |> render(:"503")
        |> halt()
    end
  end
end
