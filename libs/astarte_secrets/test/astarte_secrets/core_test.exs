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

  describe "string_to_key_type/1" do
    test "converts string key types to their atom representation" do
      assert {:ok, :es256} = Core.string_to_key_type("ecdsa-p256")
      assert {:ok, :es384} = Core.string_to_key_type("ecdsa-p384")
      assert {:ok, :rs256} = Core.string_to_key_type("rsa-2048")
      assert {:ok, :rs384} = Core.string_to_key_type("rsa-3072")
    end

    test "returns :error for unknown string" do
      assert :error = Core.string_to_key_type("unknown")
      assert :error = Core.string_to_key_type(:es256)
      assert :error = Core.string_to_key_type(nil)
    end

    test "round-trips with key_type_to_string/1" do
      for atom <- [:es256, :es384, :rs256, :rs384] do
        {:ok, string} = Core.key_type_to_string(atom)
        assert {:ok, ^atom} = Core.string_to_key_type(string)
      end
    end
  end

  describe "key_algorithm_enum/0" do
    test "returns a keyword list containing all supported algorithms" do
      enum = Core.key_algorithm_enum()
      assert Keyword.get(enum, :es256) == "ecdsa-p256"
      assert Keyword.get(enum, :es384) == "ecdsa-p384"
      assert Keyword.get(enum, :rs256) == "rsa-2048"
      assert Keyword.get(enum, :rs384) == "rsa-3072"
    end
  end

  describe "digest_type/1" do
    test "converts known digest atoms to OpenBao strings" do
      assert {:ok, "sha1"} = Core.digest_type(:sha)
      assert {:ok, "sha2-224"} = Core.digest_type(:sha224)
      assert {:ok, "sha2-256"} = Core.digest_type(:sha256)
      assert {:ok, "sha2-384"} = Core.digest_type(:sha384)
      assert {:ok, "sha2-512"} = Core.digest_type(:sha512)
      assert {:ok, "sha3-224"} = Core.digest_type(:sha3_224)
      assert {:ok, "sha3-256"} = Core.digest_type(:sha3_256)
      assert {:ok, "sha3-384"} = Core.digest_type(:sha3_384)
      assert {:ok, "sha3-512"} = Core.digest_type(:sha3_512)
    end

    test "returns :error for unknown digest type" do
      assert :error = Core.digest_type(:md5)
      assert :error = Core.digest_type(:unknown)
    end
  end

  describe "encode_key_to_pkcs8/1" do
    test "encodes an ECC key to PKCS8 DER binary" do
      key = ECC.generate(:es256)
      pkcs8 = Core.encode_key_to_pkcs8(key)
      assert is_binary(pkcs8)
      assert byte_size(pkcs8) > 0
      # PKCS8 DER starts with sequence tag 0x30
      assert <<0x30, _rest::binary>> = pkcs8
    end

    test "encodes an RSA key to PKCS8 DER binary" do
      key = RSA.generate(:rs256)
      pkcs8 = Core.encode_key_to_pkcs8(key)
      assert is_binary(pkcs8)
      assert byte_size(pkcs8) > 0
      assert <<0x30, _rest::binary>> = pkcs8
    end
  end

  describe "prepare_import_ciphertext/2" do
    test "returns {:ok, base64_string} for valid key material and wrapping PEM" do
      wrapping_pem =
        X509.PrivateKey.new_rsa(2048)
        |> X509.PublicKey.derive()
        |> X509.PublicKey.to_pem()

      key_material = ECC.generate(:es256) |> Core.encode_key_to_pkcs8()

      assert {:ok, ciphertext} = Core.prepare_import_ciphertext(key_material, wrapping_pem)
      assert is_binary(ciphertext)
      assert {:ok, _} = Base.decode64(ciphertext)
    end

    test "returns error for invalid PEM" do
      assert {:error, :pem_decode_failed} =
               Core.prepare_import_ciphertext(<<1, 2, 3>>, "not a pem")
    end
  end

  describe "parse_json_data/1" do
    test "parses a valid JSON object with a data key" do
      json = Jason.encode!(%{"data" => %{"foo" => "bar"}})
      assert {:ok, %{"foo" => "bar"}} = Core.parse_json_data(json)
    end

    test "returns error when data key is missing" do
      json = Jason.encode!(%{"other" => "value"})
      assert {:error, _} = Core.parse_json_data(json)
    end

    test "returns error for non-JSON input" do
      assert {:error, _} = Core.parse_json_data("not json")
    end

    test "returns error for JSON array (not a map)" do
      assert {:error, _} = Core.parse_json_data("[1, 2, 3]")
    end
  end

  describe "create_keypair/4" do
    setup :http_stubs_setup

    test "returns parsed data on HTTP 200" do
      body = Jason.encode!(%{"data" => %{"name" => "my-key"}})

      expect(Client, :post, fn _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 200, body: body}}
      end)

      assert {:ok, %{"name" => "my-key"}} =
               Core.create_keypair("my-key", "ecdsa-p256", false, "ns")
    end

    test "returns :error on HTTP error response" do
      expect(Client, :post, fn _url, _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 400, body: "bad request"}}
      end)

      assert :error = Core.create_keypair("my-key", "ecdsa-p256", false, "ns")
    end
  end

  describe "get_wrapping_key/1" do
    setup :http_stubs_setup

    test "returns {:ok, pem} on 200 with valid body" do
      pem = "-----BEGIN PUBLIC KEY-----\nfake\n-----END PUBLIC KEY-----"
      body = Jason.encode!(%{"data" => %{"public_key" => pem}})

      expect(Client, :get, fn _url, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 200, body: body}}
      end)

      assert {:ok, ^pem} = Core.get_wrapping_key([])
    end

    test "returns {:error, :wrapping_key_parse_failed} when public_key is missing" do
      body = Jason.encode!(%{"data" => %{"other" => "value"}})

      expect(Client, :get, fn _url, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 200, body: body}}
      end)

      assert {:error, :wrapping_key_parse_failed} = Core.get_wrapping_key([])
    end

    test "returns :error on HTTP error" do
      expect(Client, :get, fn _url, _headers, _opts ->
        {:error, %HTTPoison.Error{reason: :econnrefused}}
      end)

      assert :error = Core.get_wrapping_key([])
    end
  end

  describe "get_key/2" do
    setup :http_stubs_setup

    test "returns {:ok, body} on HTTP 200" do
      body = Jason.encode!(%{"data" => %{"name" => "my-key"}})

      expect(Client, :get, fn _url, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 200, body: body}}
      end)

      assert {:ok, ^body} = Core.get_key("my-key", "ns")
    end

    test "returns :error on HTTP 404" do
      expect(Client, :get, fn _url, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 404}}
      end)

      assert :error = Core.get_key("missing-key", "ns")
    end

    test "returns :error on HTTP error" do
      expect(Client, :get, fn _url, _headers, _opts ->
        {:error, %HTTPoison.Error{reason: :econnrefused}}
      end)

      assert :error = Core.get_key("my-key", "ns")
    end
  end

  describe "list_keys/1" do
    setup :http_stubs_setup

    test "returns {:ok, keys} on HTTP 200 with valid body" do
      body = Jason.encode!(%{"data" => %{"keys" => ["key1", "key2"]}})

      expect(Client, :list, fn _url, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 200, body: body}}
      end)

      assert {:ok, ["key1", "key2"]} = Core.list_keys("ns")
    end

    test "returns {:ok, []} on HTTP 404" do
      expect(Client, :list, fn _url, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 404}}
      end)

      assert {:ok, []} = Core.list_keys("ns")
    end

    test "returns :error when response body is malformed" do
      expect(Client, :list, fn _url, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 200, body: "not json"}}
      end)

      assert :error = Core.list_keys("ns")
    end

    test "returns :error on HTTP error" do
      expect(Client, :list, fn _url, _headers, _opts ->
        {:error, %HTTPoison.Error{reason: :econnrefused}}
      end)

      assert :error = Core.list_keys("ns")
    end
  end

  describe "mount_transit_engine/1" do
    setup :http_stubs_setup

    test "returns :ok on HTTP 204" do
      expect(Client, :post, fn "/sys/mounts/transit", _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 204}}
      end)

      assert :ok = Core.mount_transit_engine("ns")
    end

    test "returns :ok on HTTP 400 with 'already in use' message" do
      expect(Client, :post, fn "/sys/mounts/transit", _body, _headers, _opts ->
        {:ok, %HTTPoison.Response{status_code: 400, body: "path is already in use at transit/"}}
      end)

      assert :ok = Core.mount_transit_engine("ns")
    end

    test "returns error on HTTP 400 with different message" do
      expect(Client, :post, fn "/sys/mounts/transit", _body, _headers, _opts ->
        {:ok,
         %HTTPoison.Response{
           status_code: 400,
           body: "some other error",
           headers: [],
           request: nil
         }}
      end)

      assert :error = Core.mount_transit_engine("ns")
    end

    test "returns :error on HTTP connection error" do
      expect(Client, :post, fn "/sys/mounts/transit", _body, _headers, _opts ->
        {:error, %HTTPoison.Error{reason: :econnrefused}}
      end)

      assert :error = Core.mount_transit_engine("ns")
    end
  end

  describe "get_keys_from_algorithm/2" do
    test "returns a map with key name for a valid algorithm atom" do
      unique_id = System.unique_integer([:positive])
      realm_name = "algtest_#{unique_id}"

      {:ok, ns} = Secrets.create_namespace(realm_name, :es256)

      Secrets.create_keypair("k1", :es256, namespace: ns)

      result = Core.get_keys_from_algorithm(realm_name, :es256)
      assert {:ok, %{"ecdsa-p256" => keys}} = result
      assert "k1" in keys
    end

    test "returns a map with multiple key names when multiple keys exist for the algorithm" do
      unique_id = System.unique_integer([:positive])
      realm_name = "algtest_multiple_#{unique_id}"

      {:ok, ns} = Secrets.create_namespace(realm_name, :es256)

      Secrets.create_keypair("key_one", :es256, namespace: ns)
      Secrets.create_keypair("key_two", :es256, namespace: ns)

      result = Core.get_keys_from_algorithm(realm_name, :es256)

      assert {:ok, %{"ecdsa-p256" => keys}} = result
      assert "key_one" in keys
      assert "key_two" in keys
      assert length(keys) == 2
    end

    test "returns an empty map when no keys exist for the algorithm" do
      unique_id = System.unique_integer([:positive])
      realm_name = "algtest_empty_#{unique_id}"

      assert {:ok, %{}} = Core.get_keys_from_algorithm(realm_name, :es384)
    end
  end

  describe "find_key/3" do
    test "returns {:ok, key} when the key exists" do
      unique_id = System.unique_integer([:positive])
      realm_name = "findtest_#{unique_id}"

      {:ok, ns} = Secrets.create_namespace(realm_name, :es256)

      Secrets.create_keypair("find-me", :es256, namespace: ns)

      assert {:ok, key} = Core.find_key(realm_name, "find-me", :es256)
      assert key.name == "find-me"
    end

    test "returns :not_found when key does not exist" do
      unique_id = System.unique_integer([:positive])
      realm_name = "findtest_missing_#{unique_id}"

      {:ok, _} = Secrets.create_namespace(realm_name, :es256)

      assert :not_found = Core.find_key(realm_name, "no-such-key", :es256)
    end

    test "returns :not_found when key exists under a different algorithm" do
      unique_id = System.unique_integer([:positive])
      realm_name = "findtest_alg_#{unique_id}"

      {:ok, ns} = Secrets.create_namespace(realm_name, :es256)

      Secrets.create_keypair("find-me", :es256, namespace: ns)

      assert :not_found = Core.find_key(realm_name, "find-me", :es384)
    end
  end
end
