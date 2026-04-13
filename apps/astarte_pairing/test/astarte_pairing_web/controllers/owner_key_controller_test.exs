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
  alias Astarte.Secrets.OwnerKeyInitialization
  alias Astarte.Secrets.OwnerKeyInitializationOptions
  alias COSE.Keys

  setup :verify_on_exit!

  describe "POST /fdo/owner_key" do
    setup :owner_key_setup

    test "rejects the request if no correct key action is specified", context do
      %{
        auth_conn: conn,
        owner_key_path: path,
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
        owner_key_path: path,
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
        owner_key_path: path,
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
        owner_key_path: path,
        create_key_payload: payload,
        openbao_namespace: namespace
      } = context

      on_exit(fn -> cleanup_keys(namespace) end)

      public_key_created =
        conn
        |> post(path, payload)
        |> response(200)

      {:ok, %Key{public_pem: public_key_retrieved}} =
        Secrets.get_key(payload[:data][:key_name], namespace: namespace)

      assert public_key_created == public_key_retrieved
    end

    test "rejects the request if no key data is specified while uploading key", context do
      %{
        auth_conn: conn,
        owner_key_path: path,
        upload_key_payload: payload
      } = context

      {_, payload_no_key_data} = pop_in(payload, [:data, :key_data])

      conn
      |> post(path, payload_no_key_data)
      |> response(422)
    end

    test "rejects the request if an invalid key body is passed while uploading key",
         context do
      %{
        auth_conn: conn,
        owner_key_path: path,
        upload_key_payload: payload
      } = context

      payload_wrong_key_data =
        update_in(payload, [:data, :key_data], fn _ -> "invalid_key_body" end)

      conn
      |> post(path, payload_wrong_key_data)
      |> response(422)
    end

    test "uploads in OpenBao a key of the chosen type (EC256)", context do
      %{
        auth_conn: conn,
        owner_key_path: path,
        upload_key_payload: payload,
        openbao_namespace: namespace
      } = context

      on_exit(fn -> cleanup_keys(namespace) end)

      conn
      |> post(path, payload)
      |> response(200)

      assert {:ok, %Key{public_pem: public_key_retrieved}} =
               Secrets.get_key(payload[:data][:key_name], namespace: namespace)

      # we load a private key PEM, OpenBao returns a public key PEM. Need to compare them
      assert private_pem_public_pem_match?(payload[:data][:key_data], public_key_retrieved)
    end

    test "returns a warning if a key with the same name has been already imported in OpenBao",
         context do
      %{
        auth_conn: conn,
        owner_key_path: path,
        upload_key_payload: payload,
        openbao_namespace: namespace
      } = context

      on_exit(fn -> cleanup_keys(namespace) end)

      payload_duplicated_key =
        update_in(payload, [:data, :key_name], fn _ -> "duplicated_key" end)

      conn
      |> post(path, payload_duplicated_key)
      |> response(200)

      resp_message =
        conn
        |> post(path, payload_duplicated_key)
        |> response(409)

      assert resp_message =~ "has already been imported"
    end
  end

  describe "/fdo/owner_keys listing" do
    setup :owner_keys_setup

    test "list 4 keys in p256 group", context do
      %{
        auth_conn: conn,
        openbao_namespace: namespace,
        list_path: path
      } = context

      on_exit(fn -> cleanup_keys(namespace) end)

      keys =
        conn
        |> get(path)
        |> response(200)

      keys = Jason.decode!(keys)

      assert keys == %{
               "es256" => [
                 "key_to_create",
                 "key_to_create1",
                 "key_to_create2",
                 "key_to_create3"
               ],
               "es384" => [],
               "rs256" => [],
               "rs384" => []
             }
    end
  end

  defp owner_key_setup(context) do
    %{auth_conn: conn, realm_name: realm_name} = context
    owner_key_path = owner_key_path(conn, :create_or_upload_key, realm_name)

    create_key_payload = %{
      data: %{
        action: "create",
        key_name: "key_to_create",
        key_algorithm: "ecdsa-p256"
      }
    }

    upload_key_payload = %{
      data: %{
        action: "upload",
        key_name: "key_to_upload",
        key_data: Keys.ECC.generate(:es256) |> Keys.to_pem()
      }
    }

    {:ok, namespace_es256} = Secrets.create_namespace(realm_name, :es256)

    %{
      owner_key_path: owner_key_path,
      create_key_payload: create_key_payload,
      upload_key_payload: upload_key_payload,
      openbao_namespace: namespace_es256
    }
  end

  defp owner_keys_setup(context) do
    %{auth_conn: conn, realm_name: realm_name} = context
    list_path = owner_key_path(conn, :list_keys, realm_name)

    {:ok, namespace_es256} = Secrets.create_namespace(realm_name, :es256)

    [
      %{
        action: "create",
        key_name: "key_to_create",
        key_algorithm: "ecdsa-p256"
      },
      %{
        action: "create",
        key_name: "key_to_create1",
        key_algorithm: "ecdsa-p256"
      },
      %{
        action: "create",
        key_name: "key_to_create2",
        key_algorithm: "ecdsa-p256"
      },
      %{
        action: "create",
        key_name: "key_to_create3",
        key_algorithm: "ecdsa-p256"
      }
    ]
    |> Enum.each(fn data ->
      create_or_upload_changeset =
        OwnerKeyInitializationOptions.changeset(%OwnerKeyInitializationOptions{}, data)

      {:ok, create_or_upload_changeset} =
        Ecto.Changeset.apply_action(create_or_upload_changeset, :insert)

      {:ok, _} =
        OwnerKeyInitialization.create_or_upload(create_or_upload_changeset, realm_name)
    end)

    %{list_path: list_path, openbao_namespace: namespace_es256}
  end

  # simple version, works only for EC keys
  # TODO implement using COSE functions
  defp private_pem_public_pem_match?(private_pem, public_pem) do
    private_pem_decoded = decode_pem(private_pem) |> extract_public()
    public_pem_decoded = decode_pem(public_pem)

    private_pem_decoded == public_pem_decoded
  end

  defp decode_pem(pem_string) do
    [entry] = :public_key.pem_decode(pem_string)
    :public_key.pem_entry_decode(entry)
  end

  defp extract_public({:ECPrivateKey, _version, _priv, params, pub_bytes, _attributes}) do
    {{:ECPoint, pub_bytes}, params}
  end

  defp cleanup_keys(namespace) do
    {:ok, keys_to_delete} = Secrets.list_keys_names(namespace: namespace)

    Enum.each(keys_to_delete, fn key ->
      Secrets.enable_key_deletion(key, namespace: namespace)
      Secrets.delete_key(key, namespace: namespace)
    end)
  end
end
