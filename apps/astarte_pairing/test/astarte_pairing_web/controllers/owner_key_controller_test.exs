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

defmodule Astarte.PairingWeb.Controllers.OwnerKeyControllerTest do
  use Astarte.Cases.Conn, async: true
  use Astarte.Cases.Data
  use Mimic

  alias Astarte.Pairing.Config
  alias Astarte.Secrets
  alias Astarte.Secrets.Key

  setup :verify_on_exit!

  describe "/fdo/owner_key" do
    setup :owner_key_setup

    test "rejects the request if no correct key action is specified", context do
      %{
        auth_conn: conn,
        create_path: path,
        create_key_payload: payload
      } = context

      payload_wrong_action =
        update_in(payload, [:data, :action], fn _ -> "unsupported_action" end)

      conn
      |> post(path, payload_wrong_action)
      |> response(422)
    end

    test "rejects the request if no algorithm is specified while creating key", context do
      %{
        auth_conn: conn,
        create_path: path,
        create_key_payload: payload
      } = context

      {_, payload_no_key_alg} = pop_in(payload, [:data, :key_algorithm])

      conn
      |> post(path, payload_no_key_alg)
      |> response(422)
    end

    test "rejects the request if unsupported key algorithm is chosen while creating key",
         context do
      %{
        auth_conn: conn,
        create_path: path,
        create_key_payload: payload
      } = context

      payload_wrong_key_alg =
        update_in(payload, [:data, :key_algorithm], fn _ -> "unsupported_algorithm" end)

      conn
      |> post(path, payload_wrong_key_alg)
      |> response(422)
    end

    test "creates in OpenBao a key of the chosen type (EC256)", context do
      %{
        auth_conn: conn,
        create_path: path,
        create_key_payload: payload,
        openbao_namespace: namespace
      } = context

      public_key_created =
        conn
        |> post(path, payload)
        |> response(200)

      {:ok, %Key{public_pem: public_key_retrieved}} =
        Secrets.get_key(payload[:data][:key_name], namespace: namespace)

      assert public_key_created == public_key_retrieved
    end

    test "returns a 404 error if FDO feature is disabled", context do
      %{auth_conn: conn, create_path: path, create_key_payload: payload} = context

      stub(Config, :enable_fdo!, fn -> false end)

      conn
      |> post(path, payload)
      |> response(404)
    end
  end

  defp owner_key_setup(context) do
    %{auth_conn: conn, realm_name: realm_name} = context
    create_path = owner_key_path(conn, :create_or_upload_key, realm_name)

    create_key_payload = %{
      data: %{
        action: "create",
        key_name: "key_to_create",
        key_algorithm: "ecdsa-p256"
      }
    }

    {:ok, namespace_es256} = Secrets.create_namespace(realm_name, :es256)

    %{
      create_path: create_path,
      create_key_payload: create_key_payload,
      openbao_namespace: namespace_es256
    }
  end
end
