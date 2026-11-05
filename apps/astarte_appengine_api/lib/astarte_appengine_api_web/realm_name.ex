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

defmodule Astarte.AppEngine.APIWeb.RealmName do
  @moduledoc """
  The name of the realm a request refers to.
  """

  alias Astarte.Auth.GraphQL.Plug.Context

  @doc """
  Fetches the realm name from the request path or, on a route without one, from
  the `astarte-realm` header.
  """
  @spec fetch(Plug.Conn.t()) ::
          {:ok, String.t()} | {:error, :missing_realm | :invalid_realm_name}
  def fetch(%Plug.Conn{path_params: %{"realm_name" => realm_name}}), do: {:ok, realm_name}
  def fetch(conn), do: Context.fetch_realm_name(conn)
end
