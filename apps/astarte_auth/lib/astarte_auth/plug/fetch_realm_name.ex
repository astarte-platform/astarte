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

defmodule Astarte.Auth.Plug.FetchRealmName do
  @moduledoc """
  Assigns `:realm_name`, the realm the request refers to: the `realm_name` path
  parameter or, on a route without one, the `astarte-realm` request header. It is
  `nil` when the header is missing or not a valid realm name.
  """

  @behaviour Plug

  import Plug.Conn

  alias Astarte.Core.Realm

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{path_params: %{"realm_name" => realm_name}} = conn, _opts),
    do: assign(conn, :realm_name, realm_name)

  def call(conn, _opts) do
    realm_name = conn |> get_req_header("astarte-realm") |> find_realm_name()

    assign(conn, :realm_name, realm_name)
  end

  defp find_realm_name([realm_name | _]) do
    if Realm.valid_name?(realm_name), do: realm_name
  end

  defp find_realm_name([]), do: nil
end
