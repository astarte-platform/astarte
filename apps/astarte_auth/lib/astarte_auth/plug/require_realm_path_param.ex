#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.Auth.Plug.RequireRealmPathParam do
  @moduledoc """
  Assigns `:realm_name` from the `realm_name` path parameter, the only place a
  REST request names its realm.
  """

  @behaviour Plug

  import Plug.Conn

  alias Astarte.Core.Realm

  @invalid_realm_name_body Jason.encode!(%{errors: %{detail: "Invalid realm name"}})

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    realm_name = Map.fetch!(conn.path_params, "realm_name")

    if Realm.valid_name?(realm_name) do
      assign(conn, :realm_name, realm_name)
    else
      conn
      |> put_resp_content_type("application/json")
      |> send_resp(401, @invalid_realm_name_body)
      |> halt()
    end
  end
end
