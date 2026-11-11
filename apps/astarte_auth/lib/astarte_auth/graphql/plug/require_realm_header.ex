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

defmodule Astarte.Auth.GraphQL.Plug.RequireRealmHeader do
  @moduledoc """
  Assigns `:realm_name` from the `astarte-realm` request header, the only place a
  GraphQL request names its realm.
  """

  @behaviour Plug

  import Plug.Conn

  alias Astarte.Core.Realm

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(conn, _opts) do
    case get_req_header(conn, "astarte-realm") do
      [] -> halt_with_error(conn, "Missing the astarte-realm header")
      [realm_name | _] -> assign_realm_name(conn, realm_name)
    end
  end

  defp assign_realm_name(conn, realm_name) do
    if Realm.valid_name?(realm_name) do
      assign(conn, :realm_name, realm_name)
    else
      halt_with_error(conn, "Invalid realm name in the astarte-realm header")
    end
  end

  defp halt_with_error(conn, message) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{errors: [%{message: message}]}))
    |> halt()
  end
end
