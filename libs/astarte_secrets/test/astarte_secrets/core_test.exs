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

defmodule Astarte.Secrets.CoreTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Astarte.Secrets
  alias Astarte.Secrets.Client
  alias Astarte.Secrets.Config
  alias Astarte.Secrets.Core
  alias COSE.Keys.ECC
  alias COSE.Keys.RSA

  import Astarte.Helpers.Namespace

  describe "namespace_tokens/3" do
    setup :namespace_tokens_setup

    test "always starts with fdo_owner_keys", context do
      %{realm_name: realm_name, user_id: user_id, key_algorithm: key_algorithm} = context

      assert ["fdo_owner_keys" | _] =
               Core.namespace_tokens(realm_name, user_id, key_algorithm)
    end

    test "uses default_instance for empty astarte_instance_id", context do
      %{realm_name: realm_name, user_id: user_id, key_algorithm: key_algorithm} = context

      assert [_, "default_instance" | _] =
               Core.namespace_tokens(realm_name, user_id, key_algorithm)
    end

    @tag instance: "someinstance"
    test "uses nested namespaces when instance id is set", context do
      %{
        realm_name: realm_name,
        user_id: user_id,
        key_algorithm: key_algorithm,
        instance: instance
      } = context

      assert [_, "instance", ^instance | _] =
               Core.namespace_tokens(realm_name, user_id, key_algorithm)
    end

    test "places realm name after instance", context do
      %{realm_name: realm_name, user_id: user_id, key_algorithm: key_algorithm} = context

      assert [_, _, ^realm_name | _] =
               Core.namespace_tokens(realm_name, user_id, key_algorithm)
    end

    test "uses default_user for empty user id", context do
      %{realm_name: realm_name, key_algorithm: key_algorithm} = context

      assert [_, _, _, "default_user" | _] =
               Core.namespace_tokens(realm_name, nil, key_algorithm)
    end

    @tag user_id: "userid"
    test "uses nested namespaces when user id is set", context do
      %{realm_name: realm_name, user_id: user_id, key_algorithm: key_algorithm} = context

      assert [_, _, _, "user_id", ^user_id | _] =
               Core.namespace_tokens(realm_name, user_id, key_algorithm)
    end

    test "ends with key algorithm", context do
      %{realm_name: realm_name, user_id: user_id, key_algorithm: key_algorithm} = context

      assert [_, _, _, _, ^key_algorithm] =
               Core.namespace_tokens(realm_name, user_id, key_algorithm)
    end

    @tag instance: "someinstance"
    @tag user_id: "user_id"
    test "produces expected result", context do
      %{
        realm_name: realm_name,
        user_id: user_id,
        key_algorithm: key_algorithm,
        instance: instance
      } = context

      assert [
               "fdo_owner_keys",
               "instance",
               instance,
               realm_name,
               "user_id",
               user_id,
               key_algorithm
             ] == Core.namespace_tokens(realm_name, user_id, key_algorithm)
    end
  end

  describe "create_nested_namespace/1" do
    setup :create_nested_namespace_setup

    test "returns the final namespace created", context do
      %{final_namespace: namespace, tokens: tokens} = context

      assert {:ok, namespace} == Core.create_nested_namespace(tokens)
    end

    test "creates nested namespaces", context do
      %{tokens: tokens, all_namespaces: namespaces} = context
      namespaces = MapSet.new(namespaces)

      {:ok, _} = Core.create_nested_namespace(tokens)
      {:ok, fetched_namespaces} = Secrets.list_namespaces()
      fetched_namespaces = MapSet.new(fetched_namespaces)

      assert MapSet.subset?(namespaces, fetched_namespaces)
    end
  end

  defp create_nested_namespace_setup(_context) do
    namespace = "some/namespace/path"
    tokens = namespace |> String.split("/", trim: true)
    all_namespaces = ["some/", "some/namespace/", "some/namespace/path/"]

    %{final_namespace: namespace, tokens: tokens, all_namespaces: all_namespaces}
  end

  describe "key_type_to_string/1" do
    test "converts known key types to their string representation" do
      assert {:ok, "ecdsa-p256"} = Core.key_type_to_string(:es256)
      assert {:ok, "ecdsa-p384"} = Core.key_type_to_string(:es384)
      assert {:ok, "rsa-2048"} = Core.key_type_to_string(:rs256)
      assert {:ok, "rsa-3072"} = Core.key_type_to_string(:rs384)
    end

    test "returns :error for unknown key type" do
      assert :error = Core.key_type_to_string(:unknown)
      assert :error = Core.key_type_to_string("ecdsa-p256")
      assert :error = Core.key_type_to_string(nil)
    end
  end

  describe "import_key/4" do
    setup :http_stubs_setup

    setup do
      ciphertext = Base.encode64(:crypto.strong_rand_bytes(32))
      %{ciphertext: ciphertext}
    end

    test "returns :ok on HTTP 204", %{ciphertext: ciphertext} do
      expect(Client, :post, fn _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 204}}
      end)

      assert :ok = Core.import_key("my-key", "ecdsa-p256", ciphertext)
    end

    test "returns :error on HTTP error response", %{ciphertext: ciphertext} do
      expect(Client, :post, fn _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 400, body: "bad request"}}
      end)

      assert :error = Core.import_key("my-key", "ecdsa-p256", ciphertext)
    end

    test "sends correct key type and ciphertext in request body", %{ciphertext: ciphertext} do
      expect(Client, :post, fn _url, body_str, _headers, _opts ->
        {:ok, decoded} = Jason.decode(body_str)
        assert decoded["type"] == "ecdsa-p256"
        assert decoded["ciphertext"] == ciphertext
        {:ok, %HTTPoison.Response{status_code: 204}}
      end)

      assert :ok = Core.import_key("my-key", "ecdsa-p256", ciphertext)
    end
  end

  describe "import_key/4 integration" do
    setup do
      token = Config.bao_token!()

      unique_id = System.unique_integer([:positive])
      realm_name = "test_realm_#{unique_id}"

      {:ok, namespace} = Secrets.create_namespace(realm_name, nil, :es256)

      opts = [token: token, namespace: namespace]

      %{unique_id: unique_id, opts: opts}
    end

    test "successfully imports an EC-256 key into OpenBao", %{unique_id: uid, opts: opts} do
      key_name = "imported_ec256_#{uid}"
      ec_key = ECC.generate(:es256)

      assert :ok = Secrets.import_key(key_name, :es256, ec_key, opts)

      assert {:ok, raw_sig} = Secrets.sign(key_name, "test_payload", :es256, :sha256, opts)
      assert is_binary(raw_sig)
      assert byte_size(raw_sig) == 64

      expected_pub_pem =
        ec_key
        |> ECC.to_record()
        |> X509.PublicKey.derive()
        |> X509.PublicKey.to_pem()
        |> String.trim_trailing()

      assert {:ok, key_data} = Secrets.get_key(key_name, opts)
      stored_pem = key_data.public_pem |> String.trim_trailing()
      assert expected_pub_pem == stored_pem
    end

    test "successfully imports an RSA-2048 key into OpenBao", %{unique_id: uid, opts: opts} do
      key_name = "imported_rsa2048_#{uid}"
      rsa_key = RSA.generate(:rs256)

      assert :ok = Secrets.import_key(key_name, :rs256, rsa_key, opts)

      assert {:ok, raw_sig} = Secrets.sign(key_name, "test_payload", :rs256, :sha256, opts)
      assert is_binary(raw_sig)
      assert byte_size(raw_sig) == 256

      expected_pub_pem =
        rsa_key
        |> RSA.to_record()
        |> X509.PublicKey.derive()
        |> X509.PublicKey.to_pem()
        |> String.trim_trailing()

      assert {:ok, key_data} = Secrets.get_key(key_name, opts)
      stored_pem = key_data.public_pem |> String.trim_trailing()
      assert expected_pub_pem == stored_pem
    end

    test "successfully imports an RSA-3072 key into OpenBao", %{unique_id: uid, opts: opts} do
      key_name = "imported_rsa3072_#{uid}"
      rsa_key = RSA.generate(:rs384)

      assert :ok = Secrets.import_key(key_name, :rs384, rsa_key, opts)

      assert {:ok, raw_sig} = Secrets.sign(key_name, "test_payload", :rs384, :sha384, opts)
      assert is_binary(raw_sig)
      assert byte_size(raw_sig) == 384

      expected_pub_pem =
        rsa_key
        |> RSA.to_record()
        |> X509.PublicKey.derive()
        |> X509.PublicKey.to_pem()
        |> String.trim_trailing()

      assert {:ok, key_data} = Secrets.get_key(key_name, opts)
      stored_pem = key_data.public_pem |> String.trim_trailing()
      assert expected_pub_pem == stored_pem
    end

    test "returns error if the key has already been imported", %{unique_id: uid, opts: opts} do
      key_name = "imported_ec256_#{uid}"
      ec_key = ECC.generate(:es256)

      assert :ok = Secrets.import_key(key_name, :es256, ec_key, opts)
      assert {:error, :key_already_imported} = Secrets.import_key(key_name, :es256, ec_key, opts)
    end
  end

  defp http_stubs_setup(_context) do
    Config
    |> stub(:bao_url!, fn -> "http://localhost:8200" end)
    |> stub(:bao_token!, fn -> "root" end)
    |> stub(:bao_ssl_enabled!, fn -> false end)

    :ok
  end
end
