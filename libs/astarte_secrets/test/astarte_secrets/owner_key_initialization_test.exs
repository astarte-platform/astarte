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

defmodule Astarte.Secrets.OwnerKeyInitializationTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.Secrets
  alias Astarte.Secrets.OwnerKeyInitialization
  alias Astarte.Secrets.OwnerKeyInitializationOptions

  setup :verify_on_exit!

  # A P-256 EC private key PEM, parseable by COSE.Keys.from_pem/1
  # (yields %COSE.Keys.ECC{alg: :es256}).
  @p256_private_key_pem """
  -----BEGIN EC PRIVATE KEY-----
  MHcCAQEEIFlbTEE1Ce+RSqhU8FqxsY7eNb9BaBWOTw6qFv7l0DZtoAoGCCqGSM49
  AwEHoUQDQgAEocPEIHIrn08VRO5zkkDztwp72Sw0BSm0mZeLgOKkHLUPdVFFlc0E
  O82b1/S2Cwzwh8MIDDx0CN2b+IBl5bRwOw==
  -----END EC PRIVATE KEY-----
  """

  # A SubjectPublicKeyInfo PEM: valid PEM syntax but not a private key,
  # so COSE.Keys.from_pem/1 returns :error (used for the invalid-upload path).
  @public_key_pem """
  -----BEGIN PUBLIC KEY-----
  MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAES+TkA7VtJQv9YQ75yl5btXKR/cso
  yfLzYWUTgxViGMfJkvql4W3zrtRaVPU9I06TOHFC2Mwy+9S3A7UWv/EWtg==
  -----END PUBLIC KEY-----
  """

  @sample_namespace "fdo_owner_keys/test_realm/ecdsa-p256"
  @sample_realm "test_realm"
  @sample_key_name "owner_key"

  describe "create_or_upload/2 with action: \"create\"" do
    setup do
      stub(Secrets, :create_namespace, fn _realm, _alg ->
        {:ok, @sample_namespace}
      end)

      :ok
    end

    test "returns {:ok, public_key_pem} on success" do
      public_key_pem = "-----BEGIN PUBLIC KEY-----\nMFk...\n-----END PUBLIC KEY-----\n"

      stub(Secrets, :create_keypair, fn _key_name, _alg, _opts ->
        {:ok, %{"keys" => %{"1" => %{"public_key" => public_key_pem}}}}
      end)

      opts = %OwnerKeyInitializationOptions{
        action: "create",
        key_name: @sample_key_name,
        key_algorithm: "ecdsa-p256"
      }

      assert {:ok, ^public_key_pem} = OwnerKeyInitialization.create_or_upload(opts, @sample_realm)
    end

    test "calls create_namespace with the realm name and resolved algorithm" do
      stub(Secrets, :create_keypair, fn _key_name, _alg, _opts ->
        {:ok, %{"keys" => %{"1" => %{"public_key" => "some_pem"}}}}
      end)

      expect(Secrets, :create_namespace, fn realm, alg ->
        assert realm == @sample_realm
        assert alg == :es256
        {:ok, @sample_namespace}
      end)

      opts = %OwnerKeyInitializationOptions{
        action: "create",
        key_name: @sample_key_name,
        key_algorithm: "ecdsa-p256"
      }

      OwnerKeyInitialization.create_or_upload(opts, @sample_realm)
    end

    test "calls create_keypair with the key name and resolved algorithm" do
      expect(Secrets, :create_keypair, fn key_name, alg, _opts ->
        assert key_name == @sample_key_name
        assert alg == :es256
        {:ok, %{"keys" => %{"1" => %{"public_key" => "pem"}}}}
      end)

      opts = %OwnerKeyInitializationOptions{
        action: "create",
        key_name: @sample_key_name,
        key_algorithm: "ecdsa-p256"
      }

      OwnerKeyInitialization.create_or_upload(opts, @sample_realm)
    end

    test "works with ecdsa-p384 algorithm" do
      public_key_pem = "-----BEGIN PUBLIC KEY-----\np384pem\n-----END PUBLIC KEY-----\n"

      expect(Secrets, :create_namespace, fn _realm, alg ->
        assert alg == :es384
        {:ok, "fdo_owner_keys/test_realm/ecdsa-p384"}
      end)

      stub(Secrets, :create_keypair, fn _key_name, _alg, _opts ->
        {:ok, %{"keys" => %{"1" => %{"public_key" => public_key_pem}}}}
      end)

      opts = %OwnerKeyInitializationOptions{
        action: "create",
        key_name: @sample_key_name,
        key_algorithm: "ecdsa-p384"
      }

      assert {:ok, ^public_key_pem} = OwnerKeyInitialization.create_or_upload(opts, @sample_realm)
    end

    test "works with rsa-2048 algorithm" do
      public_key_pem = "-----BEGIN PUBLIC KEY-----\nrsapem\n-----END PUBLIC KEY-----\n"

      expect(Secrets, :create_namespace, fn _realm, alg ->
        assert alg == :rs256
        {:ok, "fdo_owner_keys/test_realm/rsa-2048"}
      end)

      stub(Secrets, :create_keypair, fn _key_name, _alg, _opts ->
        {:ok, %{"keys" => %{"1" => %{"public_key" => public_key_pem}}}}
      end)

      opts = %OwnerKeyInitializationOptions{
        action: "create",
        key_name: @sample_key_name,
        key_algorithm: "rsa-2048"
      }

      assert {:ok, ^public_key_pem} = OwnerKeyInitialization.create_or_upload(opts, @sample_realm)
    end

    test "propagates error from create_keypair" do
      stub(Secrets, :create_keypair, fn _key_name, _alg, _opts ->
        {:error, :some_error}
      end)

      opts = %OwnerKeyInitializationOptions{
        action: "create",
        key_name: @sample_key_name,
        key_algorithm: "ecdsa-p256"
      }

      assert {:error, :some_error} =
               OwnerKeyInitialization.create_or_upload(opts, @sample_realm)
    end
  end

  describe "create_or_upload/2 with action: \"upload\", key not yet stored" do
    setup do
      stub(Secrets, :create_namespace, fn _realm, _alg ->
        {:ok, @sample_namespace}
      end)

      stub(Secrets, :get_key, fn _key_name, _opts ->
        {:error, :not_found}
      end)

      stub(Secrets, :import_key, fn _key_name, _alg, _key_body, _opts ->
        :ok
      end)

      :ok
    end

    test "returns {:ok, \"\"} when a valid P-256 PEM is uploaded and key is new" do
      opts = %OwnerKeyInitializationOptions{
        action: "upload",
        key_name: @sample_key_name,
        key_data: @p256_private_key_pem
      }

      assert {:ok, ""} = OwnerKeyInitialization.create_or_upload(opts, @sample_realm)
    end

    test "calls create_namespace with the realm and the algorithm from the decoded key" do
      expect(Secrets, :create_namespace, fn realm, alg ->
        assert realm == @sample_realm
        assert alg == :es256
        {:ok, @sample_namespace}
      end)

      opts = %OwnerKeyInitializationOptions{
        action: "upload",
        key_name: @sample_key_name,
        key_data: @p256_private_key_pem
      }

      OwnerKeyInitialization.create_or_upload(opts, @sample_realm)
    end

    test "calls import_key with the correct key_name and namespace" do
      expect(Secrets, :import_key, fn key_name, _alg, _key_body, opts ->
        assert key_name == @sample_key_name
        assert opts[:namespace] == @sample_namespace
        :ok
      end)

      opts = %OwnerKeyInitializationOptions{
        action: "upload",
        key_name: @sample_key_name,
        key_data: @p256_private_key_pem
      }

      OwnerKeyInitialization.create_or_upload(opts, @sample_realm)
    end

    test "propagates error from import_key" do
      stub(Secrets, :import_key, fn _key_name, _alg, _key_body, _opts ->
        {:error, :vault_error}
      end)

      opts = %OwnerKeyInitializationOptions{
        action: "upload",
        key_name: @sample_key_name,
        key_data: @p256_private_key_pem
      }

      assert {:error, :vault_error} =
               OwnerKeyInitialization.create_or_upload(opts, @sample_realm)
    end
  end

  describe "create_or_upload/2 with action: \"upload\", key already stored" do
    setup do
      stub(Secrets, :create_namespace, fn _realm, _alg ->
        {:ok, @sample_namespace}
      end)

      :ok
    end

    test "returns {:ok, message} without calling import_key" do
      expect(Secrets, :get_key, fn key_name, _opts ->
        {:ok, %{name: key_name}}
      end)

      # import_key should NOT be called; no stub/expect means Mimic will raise if called
      opts = %OwnerKeyInitializationOptions{
        action: "upload",
        key_name: @sample_key_name,
        key_data: @p256_private_key_pem
      }

      assert {:error, {:already_imported, message}} =
               OwnerKeyInitialization.create_or_upload(opts, @sample_realm)

      assert message =~ @sample_key_name
      assert message =~ "already been imported"
    end

    test "message contains the key name" do
      stub(Secrets, :get_key, fn key_name, _opts ->
        {:ok, %{name: key_name}}
      end)

      custom_key_name = "my_custom_key"

      opts = %OwnerKeyInitializationOptions{
        action: "upload",
        key_name: custom_key_name,
        key_data: @p256_private_key_pem
      }

      assert {:error, {:already_imported, message}} =
               OwnerKeyInitialization.create_or_upload(opts, @sample_realm)

      assert message =~ custom_key_name
    end
  end

  describe "create_or_upload/2 with action: \"upload\" and invalid key_data" do
    test "returns {:error, :unprocessable_key} for non-PEM data" do
      opts = %OwnerKeyInitializationOptions{
        action: "upload",
        key_name: @sample_key_name,
        key_data: "this is not a valid PEM key"
      }

      assert {:error, :unprocessable_key} =
               OwnerKeyInitialization.create_or_upload(opts, @sample_realm)
    end

    test "returns {:error, :unprocessable_key} for empty key_data" do
      opts = %OwnerKeyInitializationOptions{
        action: "upload",
        key_name: @sample_key_name,
        key_data: ""
      }

      assert {:error, :unprocessable_key} =
               OwnerKeyInitialization.create_or_upload(opts, @sample_realm)
    end

    test "returns {:error, :unprocessable_key} for a public key PEM (not a private key)" do
      # COSE.Keys.from_pem/1 only handles private keys; a SubjectPublicKeyInfo PEM
      # parses but does not match any private-key record and returns :error.
      opts = %OwnerKeyInitializationOptions{
        action: "upload",
        key_name: @sample_key_name,
        key_data: @public_key_pem
      }

      assert {:error, :unprocessable_key} =
               OwnerKeyInitialization.create_or_upload(opts, @sample_realm)
    end
  end
end
