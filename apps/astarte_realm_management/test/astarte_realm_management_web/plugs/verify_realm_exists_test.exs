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

defmodule Astarte.RealmManagementWeb.Plug.VerifyRealmExistsTest do
  use Astarte.Cases.Data, async: true
  use Astarte.RealmManagementWeb.ConnCase
  use Mimic

  alias Astarte.RealmManagement.RealmConfig.Queries
  alias Astarte.RealmManagementWeb.Plug.VerifyRealmExists

  describe "init/1" do
    test "returns opts unchanged" do
      opts = [some: :option]
      assert VerifyRealmExists.init(opts) == opts
    end
  end

  describe "call/2" do
    setup %{conn: conn, realm_name: realm_name} do
      conn =
        conn
        |> Plug.Conn.put_private(:phoenix_format, "json")
        |> Map.put(:path_params, %{"realm_name" => realm_name})

      {:ok, conn: conn}
    end

    test "passes through unchanged when realm exists", %{conn: conn} do
      result = VerifyRealmExists.call(conn, VerifyRealmExists.init([]))

      refute result.halted
    end

    test "returns 403 Forbidden and halts when realm does not exist", %{conn: conn} do
      conn = Map.put(conn, :path_params, %{"realm_name" => "nonexistentrealm"})

      result = VerifyRealmExists.call(conn, VerifyRealmExists.init([]))

      assert result.halted
      assert json_response(result, 403)["errors"]["detail"] == "Forbidden"
    end

    test "returns 503 Service Unavailable and halts on query error", %{conn: conn} do
      expect(Queries, :realm_existing?, fn _realm -> {:error, :database_error} end)

      result = VerifyRealmExists.call(conn, VerifyRealmExists.init([]))

      assert result.halted
      assert result.status == 503
    end
  end
end
