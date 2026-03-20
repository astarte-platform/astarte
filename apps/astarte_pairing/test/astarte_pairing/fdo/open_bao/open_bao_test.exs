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
  alias Astarte.Pairing.FDO.OpenBao.Core

  import Astarte.Helpers.OpenBao

  describe "create_namespace/3" do
    setup :namespace_tokens_setup

    test "calls core functions", context do
      %{realm_name: realm_name, user_id: user_id, key_algorithm: key_algorithm} = context

      ref = System.unique_integer()

      Core
      |> expect(:namespace_tokens, fn ^realm_name, ^user_id, ^key_algorithm -> ref end)
      |> expect(:create_nested_namespace, fn ^ref -> {:ok, ""} end)

      assert {:ok, _} = OpenBao.create_namespace(realm_name, user_id, key_algorithm)
    end
  end

  describe "successfully create and delete a key pair in OpenBao" do
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

    @tag key_type: :ec256
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

    @tag key_type: :ec384
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

    @tag key_type: :rsa2048
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

    @tag key_type: :rsa3072
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

  describe "sign/4" do
    alias Astarte.Pairing.FDO.OpenBao.Core

    setup do
      unique_id = System.unique_integer([:positive])

      %{
        key_name: "device_key",
        payload: "test_payload",
        alg: :es256,
        opts: [token: "my_token", namespace: "my_namespace_#{unique_id}"]
      }
    end

    test "delegates to Core.sign/4 with default empty options", %{
      key_name: key_name,
      payload: payload,
      alg: alg
    } do
      expect(Core, :sign, fn ^key_name, ^payload, ^alg, [] ->
        {:ok, "raw_signature"}
      end)

      assert {:ok, "raw_signature"} = OpenBao.sign(key_name, payload, alg)
    end

    test "delegates to Core.sign/4 passing opts directly", %{
      key_name: key_name,
      payload: payload,
      alg: alg,
      opts: opts
    } do
      expect(Core, :sign, fn ^key_name, ^payload, ^alg, ^opts ->
        {:ok, "raw_signature"}
      end)

      assert {:ok, "raw_signature"} = OpenBao.sign(key_name, payload, alg, opts)
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

    @tag key_type: :ec256
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

    @tag key_type: :ec384
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

    @tag key_type: :rsa2048
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

    @tag key_type: :rsa3072
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

    @tag key_type: :ec256
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

    @tag key_type: :ec384
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

    @tag key_type: :rsa2048
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

    @tag key_type: :rsa3072
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
