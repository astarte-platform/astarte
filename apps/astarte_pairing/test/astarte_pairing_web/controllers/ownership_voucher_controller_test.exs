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

defmodule Astarte.PairingWeb.Controllers.OwnershipVoucherControllerTest do
  use Astarte.PairingWeb.ConnCase, async: true
  use Astarte.Cases.Data
  use Mimic

  alias Astarte.Pairing.Queries
  alias Astarte.Pairing.FDO.Rendezvous
  alias Astarte.Pairing.Config

  import Astarte.Helpers.FDO

  @sample_params %{
    data: %{
      "ownership_voucher" => sample_voucher(),
      "private_key" => sample_private_key()
    }
  }

  setup :verify_on_exit!

  describe "/ownership" do
    setup :ownership

    test "stores the ownership voucher", context do
      %{auth_conn: conn, create_path: path, realm_name: realm_name} = context

      conn
      |> post(path, @sample_params)
      |> response(200)

      assert {:ok, _} = Queries.get_ownership_voucher(realm_name, sample_device_guid())
    end

    test "stores the owner private key", context do
      %{auth_conn: conn, create_path: path, realm_name: realm_name} = context

      conn
      |> post(path, @sample_params)
      |> response(200)

      assert {:ok, _} = Queries.get_owner_private_key(realm_name, sample_device_guid())
    end

    test "starts the to0 protocol", context do
      %{auth_conn: conn, create_path: path} = context
      sample_nonce = nonce() |> Enum.at(0)

      Rendezvous
      |> expect(:send_hello, fn -> {:ok, %{nonce: sample_nonce, headers: []}} end)
      |> expect(:register_ownership, fn _body, _headers -> {:ok, 3600} end)

      conn
      |> post(path, @sample_params)
      |> response(200)
    end

    test "returns a 404 error if FDO feature is disabled", context do
      %{auth_conn: conn, create_path: path} = context

      stub(Config, :enable_fdo!, fn -> false end)

      conn
      |> post(path, @sample_params)
      |> response(404)
    end
  end

  defp ownership(context) do
    %{auth_conn: conn, realm_name: realm_name} = context
    create_path = ownership_voucher_path(conn, :create, realm_name)
    sample_nonce = nonce() |> Enum.at(0)

    Rendezvous
    |> stub(:send_hello, fn -> {:ok, %{nonce: sample_nonce, headers: []}} end)
    |> stub(:register_ownership, fn _body, _headers -> {:ok, 3600} end)

    %{create_path: create_path}
  end
end
