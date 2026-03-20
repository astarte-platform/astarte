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

defmodule Astarte.Pairing.FDO.OpenBaoTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.Pairing.Config
  alias Astarte.Pairing.FDO.OpenBao
  alias Astarte.Pairing.FDO.OpenBao.Client
  alias Astarte.Pairing.FDO.OpenBao.Core

  import Astarte.Helpers.OpenBao

  describe "create_namespace/3" do
    setup :namespace_tokens_setup

    test "calls core functions", context do
      %{realm_name: realm_name, user_id: user_id, key_algorithm: key_algorithm} = context
      {:ok, key_algorithm_str} = Core.key_type_to_string(key_algorithm)

      ref = System.unique_integer()

      Core
      |> expect(:namespace_tokens, fn ^realm_name, ^user_id, ^key_algorithm_str -> ref end)
      |> expect(:create_nested_namespace, fn ^ref -> {:ok, ""} end)

      assert {:ok, _} = OpenBao.create_namespace(realm_name, user_id, key_algorithm)
    end
  end

  describe "successfully create and delete a key pair in OpenBao" do
    setup context do
      key_type = Map.get(context, :key_type)
      {:ok, key_type_to_string} = Core.key_type_to_string(key_type)
      realm_name = "realm#{System.unique_integer([:positive])}"
      {:ok, namespace} = OpenBao.create_namespace(realm_name, key_type)
      key_name = "some_key_#{key_type_to_string}"
      allow_key_export_and_backup = true

      opts = [
        {:token, Config.bao_token!()},
        {:namespace, namespace},
        {:allow_key_export_and_backup, allow_key_export_and_backup}
      ]

      %{
        key_name: key_name,
        key_type: key_type,
        key_type_to_string: key_type_to_string,
        allow_key_export_and_backup: allow_key_export_and_backup,
        opts: opts
      }
    end

    @tag key_type: :es256
    test "of type EC256", %{
      key_name: key_name,
      key_type: key_type,
      key_type_to_string: key_type_to_string,
      allow_key_export_and_backup: allow_key_export_and_backup,
      opts: opts
    } do
      assert {:ok, key_data} = OpenBao.create_keypair(key_name, key_type, opts)

      assert %{
               "name" => ^key_name,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data

      assert :ok == cleanup_key(key_name, opts)
    end

    @tag key_type: :es384
    test "of type EC384", %{
      key_name: key_name,
      key_type: key_type,
      key_type_to_string: key_type_to_string,
      allow_key_export_and_backup: allow_key_export_and_backup,
      opts: opts
    } do
      assert {:ok, key_data} = OpenBao.create_keypair(key_name, key_type, opts)

      assert %{
               "name" => ^key_name,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data

      assert :ok == cleanup_key(key_name, opts)
    end

    @tag key_type: :rs256
    test "of type RSA2048", %{
      key_name: key_name,
      key_type: key_type,
      key_type_to_string: key_type_to_string,
      allow_key_export_and_backup: allow_key_export_and_backup,
      opts: opts
    } do
      assert {:ok, key_data} = OpenBao.create_keypair(key_name, key_type, opts)

      assert %{
               "name" => ^key_name,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data

      assert :ok == cleanup_key(key_name, opts)
    end

    @tag key_type: :rs384
    test "of type RSA3072", %{
      key_name: key_name,
      key_type: key_type,
      key_type_to_string: key_type_to_string,
      allow_key_export_and_backup: allow_key_export_and_backup,
      opts: opts
    } do
      assert {:ok, key_data} = OpenBao.create_keypair(key_name, key_type, opts)

      assert %{
               "name" => ^key_name,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data

      assert :ok == cleanup_key(key_name, opts)
    end
  end

  describe "sign/5" do
    setup do
      # Read credentials and URL from config
      {:ok, {:token, token}} = Config.bao_authentication()

      unique_id = System.unique_integer([:positive])
      realm_name = "test_realm_#{unique_id}"

      {:ok, namespace} = OpenBao.create_namespace(realm_name, nil, :es256)

      ecdsa_key = "ecdsa_#{unique_id}"
      ecdsa384_key = "ecdsa384_#{unique_id}"
      rsa_key = "rsa_#{unique_id}"

      {:ok, _} = OpenBao.create_keypair(ecdsa_key, :es256, namespace: namespace)
      {:ok, _} = OpenBao.create_keypair(ecdsa384_key, :es384, namespace: namespace)
      {:ok, _} = OpenBao.create_keypair(rsa_key, :rs256, namespace: namespace)

      %{
        ecdsa_key: ecdsa_key,
        ecdsa384_key: ecdsa384_key,
        rsa_key: rsa_key,
        opts: [token: token, namespace: namespace]
      }
    end

    test "successfully signs with ECDSA (:es256)", %{ecdsa_key: key_name, opts: opts} do
      payload = "test_payload"

      assert {:ok, raw_sig} = OpenBao.sign(key_name, payload, :es256, :sha256, opts)

      assert is_binary(raw_sig)
      assert byte_size(raw_sig) == 64
    end

    test "successfully signs with ECDSA (:es384)", %{ecdsa384_key: key_name, opts: opts} do
      payload = "test_payload"

      assert {:ok, raw_sig} = OpenBao.sign(key_name, payload, :es384, :sha384, opts)

      assert is_binary(raw_sig)
      assert byte_size(raw_sig) == 96
    end

    test "successfully signs with RSA-PKCS1v1.5 (:rs256)", %{rsa_key: key_name, opts: opts} do
      payload = "test_payload"

      assert {:ok, raw_sig} = OpenBao.sign(key_name, payload, :rs256, :sha256, opts)

      assert is_binary(raw_sig)
      assert byte_size(raw_sig) == 256
    end

    test "successfully signs with RSA-PKCS1v1.5 (:rs384)", %{rsa_key: key_name, opts: opts} do
      payload = "test_payload"

      assert {:ok, raw_sig} = OpenBao.sign(key_name, payload, :rs384, :sha384, opts)

      assert is_binary(raw_sig)
      assert byte_size(raw_sig) == 256
    end

    test "handles missing signature in Vault JSON response", %{rsa_key: key_name, opts: opts} do
      payload = "test_payload"

      expect(Client, :post, fn _url, _body, _headers, _opts ->
        wrong_body = ~s[{"data": {"wrong_key": "value"}}]
        {:ok, %HTTPoison.Response{status_code: 200, body: wrong_body}}
      end)

      assert :error = OpenBao.sign(key_name, payload, :rs256, :sha3_256, opts)
    end

    test "returns :error for a non-existent key", %{opts: opts} do
      payload = "test_payload"

      assert :error = OpenBao.sign("random_missing_key", payload, :es256, :sha3_512, opts)
    end
  end

  describe "successfully create and fetch a key pair in OpenBao" do
    setup context do
      key_type = Map.get(context, :key_type)
      {:ok, key_type_to_string} = Core.key_type_to_string(key_type)
      realm_name = "realm#{System.unique_integer([:positive])}"
      {:ok, namespace} = OpenBao.create_namespace(realm_name, key_type_to_string)
      key_name = "some_key_#{key_type_to_string}"
      allow_key_export_and_backup = true

      opts = [
        {:token, Config.bao_token!()},
        {:namespace, namespace},
        {:allow_key_export_and_backup, allow_key_export_and_backup}
      ]

      %{
        key_name: key_name,
        key_type: key_type,
        key_type_to_string: key_type_to_string,
        allow_key_export_and_backup: allow_key_export_and_backup,
        opts: opts
      }
    end

    @tag key_type: :es256
    test "of type EC256", %{
      key_name: key_name,
      key_type: key_type,
      key_type_to_string: key_type_to_string,
      allow_key_export_and_backup: allow_key_export_and_backup,
      opts: opts
    } do
      assert {:ok, key_data} = OpenBao.create_keypair(key_name, key_type, opts)

      assert %{
               "name" => ^key_name,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data

      assert {:ok, key_data} == OpenBao.get_key(key_name, opts)
    end

    @tag key_type: :es384
    test "of type EC384", %{
      key_name: key_name,
      key_type: key_type,
      key_type_to_string: key_type_to_string,
      allow_key_export_and_backup: allow_key_export_and_backup,
      opts: opts
    } do
      assert {:ok, key_data} = OpenBao.create_keypair(key_name, key_type, opts)

      assert %{
               "name" => ^key_name,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data

      assert {:ok, key_data} == OpenBao.get_key(key_name, opts)
    end

    @tag key_type: :rs256
    test "of type RSA2048", %{
      key_name: key_name,
      key_type: key_type,
      key_type_to_string: key_type_to_string,
      allow_key_export_and_backup: allow_key_export_and_backup,
      opts: opts
    } do
      assert {:ok, key_data} = OpenBao.create_keypair(key_name, key_type, opts)

      assert %{
               "name" => ^key_name,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data

      assert {:ok, key_data} == OpenBao.get_key(key_name, opts)
    end

    @tag key_type: :rs384
    test "of type RSA3072", %{
      key_name: key_name,
      key_type: key_type,
      key_type_to_string: key_type_to_string,
      allow_key_export_and_backup: allow_key_export_and_backup,
      opts: opts
    } do
      assert {:ok, key_data} = OpenBao.create_keypair(key_name, key_type, opts)

      assert %{
               "name" => ^key_name,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data

      assert {:ok, key_data} == OpenBao.get_key(key_name, opts)
    end
  end

  describe "successfully create multiple keys and fetch their names" do
    setup context do
      key_type = Map.get(context, :key_type)
      {:ok, key_type_to_string} = Core.key_type_to_string(key_type)
      realm_name = "realm#{System.unique_integer([:positive])}"
      {:ok, namespace} = OpenBao.create_namespace(realm_name, key_type_to_string)
      key_name = "some_key_#{key_type_to_string}"
      key_name1 = "some_key_#{key_type_to_string}1"
      key_name2 = "some_key_#{key_type_to_string}2"
      allow_key_export_and_backup = true

      opts = [
        {:token, Config.bao_token!()},
        {:namespace, namespace},
        {:allow_key_export_and_backup, allow_key_export_and_backup}
      ]

      %{
        key_name: key_name,
        key_name1: key_name1,
        key_name2: key_name2,
        key_type: key_type,
        key_type_to_string: key_type_to_string,
        allow_key_export_and_backup: allow_key_export_and_backup,
        opts: opts
      }
    end

    @tag key_type: :es256
    test "of type EC256", %{
      key_name: key_name,
      key_name1: key_name1,
      key_name2: key_name2,
      key_type: key_type,
      key_type_to_string: key_type_to_string,
      allow_key_export_and_backup: allow_key_export_and_backup,
      opts: opts
    } do
      assert {:ok, key_data} = OpenBao.create_keypair(key_name, key_type, opts)
      assert {:ok, key_data1} = OpenBao.create_keypair(key_name1, key_type, opts)
      assert {:ok, key_data2} = OpenBao.create_keypair(key_name2, key_type, opts)

      assert %{
               "name" => ^key_name,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data

      assert %{
               "name" => ^key_name1,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data1

      assert %{
               "name" => ^key_name2,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data2

      assert {:ok, %{"keys" => [key_name, key_name1, key_name2]}} == OpenBao.list_keys_names(opts)
    end

    @tag key_type: :es384
    test "of type EC384", %{
      key_name: key_name,
      key_name1: key_name1,
      key_name2: key_name2,
      key_type: key_type,
      key_type_to_string: key_type_to_string,
      allow_key_export_and_backup: allow_key_export_and_backup,
      opts: opts
    } do
      assert {:ok, key_data} = OpenBao.create_keypair(key_name, key_type, opts)
      assert {:ok, key_data1} = OpenBao.create_keypair(key_name1, key_type, opts)
      assert {:ok, key_data2} = OpenBao.create_keypair(key_name2, key_type, opts)

      assert %{
               "name" => ^key_name,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data

      assert %{
               "name" => ^key_name1,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data1

      assert %{
               "name" => ^key_name2,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data2

      assert {:ok, %{"keys" => [key_name, key_name1, key_name2]}} == OpenBao.list_keys_names(opts)
    end

    @tag key_type: :rs256
    test "of type RSA2048", %{
      key_name: key_name,
      key_name1: key_name1,
      key_name2: key_name2,
      key_type: key_type,
      key_type_to_string: key_type_to_string,
      allow_key_export_and_backup: allow_key_export_and_backup,
      opts: opts
    } do
      assert {:ok, key_data} = OpenBao.create_keypair(key_name, key_type, opts)
      assert {:ok, key_data1} = OpenBao.create_keypair(key_name1, key_type, opts)
      assert {:ok, key_data2} = OpenBao.create_keypair(key_name2, key_type, opts)

      assert %{
               "name" => ^key_name,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data

      assert %{
               "name" => ^key_name1,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data1

      assert %{
               "name" => ^key_name2,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data2

      assert {:ok, %{"keys" => [key_name, key_name1, key_name2]}} == OpenBao.list_keys_names(opts)
    end

    @tag key_type: :rs384
    test "of type RSA3072", %{
      key_name: key_name,
      key_name1: key_name1,
      key_name2: key_name2,
      key_type: key_type,
      key_type_to_string: key_type_to_string,
      allow_key_export_and_backup: allow_key_export_and_backup,
      opts: opts
    } do
      assert {:ok, key_data} = OpenBao.create_keypair(key_name, key_type, opts)
      assert {:ok, key_data1} = OpenBao.create_keypair(key_name1, key_type, opts)
      assert {:ok, key_data2} = OpenBao.create_keypair(key_name2, key_type, opts)

      assert %{
               "name" => ^key_name,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data

      assert %{
               "name" => ^key_name1,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data1

      assert %{
               "name" => ^key_name2,
               "type" => ^key_type_to_string,
               "exportable" => ^allow_key_export_and_backup,
               "allow_plaintext_backup" => ^allow_key_export_and_backup
             } = key_data2

      assert {:ok, %{"keys" => [key_name, key_name1, key_name2]}} == OpenBao.list_keys_names(opts)
    end
  end

  defp cleanup_key(key_name, opts) do
    OpenBao.enable_key_deletion(key_name, opts)
    OpenBao.delete_key(key_name, opts)
  end
end
