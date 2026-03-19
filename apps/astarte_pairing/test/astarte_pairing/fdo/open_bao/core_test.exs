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

defmodule Astarte.Pairing.FDO.OpenBao.CoreTest do
  use ExUnit.Case, async: false
  use Mimic

  alias Astarte.Pairing.Config
  alias Astarte.Pairing.FDO.OpenBao
  alias Astarte.Pairing.FDO.OpenBao.Client
  alias Astarte.Pairing.FDO.OpenBao.Core

  import Astarte.Helpers.OpenBao

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
      {:ok, fetched_namespaces} = OpenBao.list_namespaces()
      fetched_namespaces = MapSet.new(fetched_namespaces)

      assert MapSet.subset?(namespaces, fetched_namespaces)
    end
  end

  describe "sign/4" do
    setup do
      # Read credentials and URL from config
      {:ok, {:token, token}} = Config.bao_authentication()

      unique_id = System.unique_integer([:positive])
      realm_name = "test_realm_#{unique_id}"

      {:ok, namespace} = OpenBao.create_namespace(realm_name, nil, "my_namespace_#{unique_id}")

      ecdsa_key = "ecdsa_#{unique_id}"
      ecdsa384_key = "ecdsa384_#{unique_id}"
      rsa_key = "rsa_#{unique_id}"

      {:ok, _} = OpenBao.create_keypair(ecdsa_key, :ec256, namespace: namespace)
      {:ok, _} = OpenBao.create_keypair(ecdsa384_key, :ec384, namespace: namespace)
      {:ok, _} = OpenBao.create_keypair(rsa_key, :rsa2048, namespace: namespace)

      %{
        ecdsa_key: ecdsa_key,
        ecdsa384_key: ecdsa384_key,
        rsa_key: rsa_key,
        opts: [token: token, namespace: namespace]
      }
    end

    test "successfully signs with ECDSA (:es256)", %{ecdsa_key: key_name, opts: opts} do
      payload = "test_payload"

      # Perform the HTTP call to OpenBao using our new Facade
      assert {:ok, raw_sig} = OpenBao.sign(key_name, payload, :es256, opts)

      # Verify it's a binary and exactly 64 bytes long
      assert is_binary(raw_sig)
      assert byte_size(raw_sig) == 64
    end

    test "successfully signs with RSA-PSS (:ps256)", %{rsa_key: key_name, opts: opts} do
      payload = "test_payload"

      # Perform the actual HTTP call to OpenBao
      assert {:ok, raw_sig} = OpenBao.sign(key_name, payload, :ps256, opts)

      # Verify it's a binary and exactly 256 bytes long
      assert is_binary(raw_sig)
      assert byte_size(raw_sig) == 256
    end

    test "successfully signs with ECDSA (:es384)", %{ecdsa384_key: key_name, opts: opts} do
      payload = "test_payload"

      assert {:ok, raw_sig} = OpenBao.sign(key_name, payload, :es384, opts)

      assert is_binary(raw_sig)
      assert byte_size(raw_sig) == 96
    end

    test "successfully signs with RSA-PKCS1v1.5 (:rs256)", %{rsa_key: key_name, opts: opts} do
      payload = "test_payload"

      assert {:ok, raw_sig} = OpenBao.sign(key_name, payload, :rs256, opts)

      assert is_binary(raw_sig)
      assert byte_size(raw_sig) == 256
    end

    test "successfully signs with RSA-PKCS1v1.5 (:rs384)", %{rsa_key: key_name, opts: opts} do
      payload = "test_payload"

      assert {:ok, raw_sig} = OpenBao.sign(key_name, payload, :rs384, opts)

      assert is_binary(raw_sig)
      assert byte_size(raw_sig) == 256
    end

    test "handles missing signature in Vault JSON response", %{rsa_key: key_name, opts: opts} do
      payload = "test_payload"

      expect(Client, :post, fn _url, _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{status_code: 200, body: "{\"data\": {\"wrong_key\": \"value\"}}"}}
      end)

      assert :error = OpenBao.sign(key_name, payload, :ps256, opts)
    end

    test "returns :error for a non-existent key", %{opts: opts} do
      payload = "test_payload"

      assert :error = OpenBao.sign("random_missing_key", payload, :es256, opts)
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
      assert {:ok, "ecdsa-p256"} = Core.key_type_to_string(:ec256)
      assert {:ok, "ecdsa-p384"} = Core.key_type_to_string(:ec384)
      assert {:ok, "rsa-2048"} = Core.key_type_to_string(:rsa2048)
      assert {:ok, "rsa-3072"} = Core.key_type_to_string(:rsa3072)
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
      rsa_priv = :public_key.generate_key({:rsa, 2048, 65_537})
      {:RSAPrivateKey, _, modulus, pub_exp, _, _, _, _, _, _, _} = rsa_priv
      rsa_pub = {:RSAPublicKey, modulus, pub_exp}
      pem_entry = :public_key.pem_entry_encode(:RSAPublicKey, rsa_pub)
      wrapping_key_pem = :public_key.pem_encode([pem_entry])
      wrapping_key_body = Jason.encode!(%{"data" => %{"public_key" => wrapping_key_pem}})
      ec_key = :public_key.generate_key({:namedCurve, :secp256r1})
      %{wrapping_key_body: wrapping_key_body, ec_key: ec_key}
    end

    test "returns {:ok, data} on HTTP 200 with JSON body", %{
      wrapping_key_body: wk_body,
      ec_key: ec_key
    } do
      body = Jason.encode!(%{"data" => %{"name" => "my-key"}})

      expect(:hackney, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok, 200, [], :wk_client}
      end)

      expect(:hackney, :body, fn :wk_client, _ -> {:ok, wk_body} end)

      expect(:hackney, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok, 200, [], :import_client}
      end)

      expect(:hackney, :body, fn :import_client, _ -> {:ok, body} end)

      assert {:ok, %{"name" => "my-key"}} = Core.import_key("my-key", "ecdsa-p256", ec_key)
    end

    test "returns :error on HTTP error response", %{
      wrapping_key_body: wk_body,
      ec_key: ec_key
    } do
      expect(:hackney, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok, 200, [], :wk_client}
      end)

      expect(:hackney, :body, fn :wk_client, _ -> {:ok, wk_body} end)

      expect(:hackney, :request, fn :post, _url, _headers, _body, _opts ->
        {:ok, 400, [], :err_client}
      end)

      expect(:hackney, :body, fn :err_client, _ -> {:ok, "bad request"} end)

      assert :error = Core.import_key("my-key", "ecdsa-p256", ec_key)
    end

    test "returns :error when wrapping key fetch fails", %{ec_key: ec_key} do
      expect(:hackney, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok, 403, []}
      end)

      assert :error = Core.import_key("my-key", "ecdsa-p256", ec_key)
    end

    test "sends correct key type and ciphertext in request body", %{
      wrapping_key_body: wk_body,
      ec_key: ec_key
    } do
      expect(:hackney, :request, fn :get, _url, _headers, _body, _opts ->
        {:ok, 200, [], :wk_client}
      end)

      expect(:hackney, :body, fn :wk_client, _ -> {:ok, wk_body} end)

      expect(:hackney, :request, fn :post, _url, _headers, body_str, _opts ->
        {:ok, decoded} = Jason.decode(body_str)
        assert decoded["type"] == "ecdsa-p256"
        assert is_binary(decoded["ciphertext"])
        {:ok, 204, []}
      end)

      assert {:ok, %{}} = Core.import_key("my-key", "ecdsa-p256", ec_key)
    end
  end

  defp http_stubs_setup(_context) do
    stub(Astarte.Pairing.Config, :bao_url!, fn -> "http://localhost:8200" end)
    stub(Astarte.Pairing.Config, :bao_token!, fn -> "root" end)
    stub(Astarte.Pairing.Config, :bao_ssl_enabled!, fn -> false end)
    :ok
  end
end
