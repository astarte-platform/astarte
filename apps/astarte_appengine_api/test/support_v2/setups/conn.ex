#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Astarte.Test.Setups.Conn do
  import Plug.Conn
  alias Phoenix.ConnTest
  alias Astarte.Test.Helpers.JWT, as: JWTHelper

  def create_conn(_context) do
    {:ok, conn: ConnTest.build_conn()}
  end

  def jwt(_context) do
    {:ok, jwt: JWTHelper.gen_jwt_all_access_token()}
  end

  def auth_conn(%{conn: conn, jwt: {jwt, _claims}}) do
    auth_conn =
      conn
      |> put_req_header("accept", "application/json")
      |> put_req_header("authorization", "bearer #{jwt}")

    {:ok, auth_conn: auth_conn}
  end
end
