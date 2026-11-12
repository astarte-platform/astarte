#
# This file is part of Astarte.
#
# Copyright 2026 Clea Srl
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

defmodule Astarte.RealmManagementWeb.GraphQL.Resolvers.ConfigResolverTest do
  use Astarte.RealmManagement.Cases.Data, async: true
  use Mimic

  alias Astarte.RealmManagement.Config
  alias Astarte.RealmManagement.Helpers.Database
  alias Astarte.RealmManagementWeb.GraphQL.Resolvers.ConfigResolver

  @new_pubkey """
  -----BEGIN PUBLIC KEY-----
  MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAvO/EdyxtA8ssxSnYQr7g
  TC41/0QMvhHMqtqYSKEs1d8brOgBg51XRz1mh04v3s/k85kZq+MB4lrKzUxu0781
  MPkZpSEHU2ICD/kzE5DUDcwgvsnTBVGFX8UuGnCOICEV6rtjA+6G7Q1rEmZ017xc
  lCVz0J0EzzTzBoB1p7x56wbIDn2t7QHMkqVOIpgc+2wZqVYcxogMjGU+QcfGRFNU
  Q+qn3BHVDi5yY75LCvT8h4rvmhK30NOSVn1V8583D7uxrVY/fh/bhlMQ0AjPZo9g
  YeilQGMReWd3haRok4RT8MTThQfEJNeDZXLoZetz4ukPKInu0uE4zSAOUxkxvH6w
  MQIDAQAB
  -----END PUBLIC KEY-----
  """

  @malformed_pubkey """
  -----BEGIN PUBLIC KEY-----
  MFYwEAYHKoZIzj0CAQYAoDQgAE6ssZpw4aj98a1hDKM
  +bxRibfFC0G6SugduGzqIACSdIiLEn4Nubx2jt4tHDpel0BIrYKlCw==
  -----END PUBLIC KEY-----
  """

  @update_attrs %{"jwt_public_key_pem" => @new_pubkey}
  @invalid_pubkey_attrs %{"jwt_public_key_pem" => "invalid"}
  @malformed_pubkey_attrs %{"jwt_public_key_pem" => @malformed_pubkey}

  setup do
    # Disable the auth since we will mess with the public key
    Config
    |> stub(:authentication_disabled?, fn -> true end)

    :ok
  end

  setup %{realm_name: realm_name, jwt_public_key: key} do
    Database.insert_public_key!(realm_name, key)

    resolution = %{
      context: %{
        realm_name: realm_name
      }
    }

    %{resolution: resolution}
  end

  describe "get_auth_config/3" do
    test "returns the auth config", %{resolution: resolution, jwt_public_key: key} do
      assert {:ok, %{jwt_public_key_pem: ^key}} =
               ConfigResolver.get_auth_config(nil, %{}, resolution)
    end
  end

  describe "update_auth_config/3" do
    test "does not update auth config and renders errors when no public key is provided", %{
      resolution: resolution
    } do
      assert {:error, error_msg} =
               ConfigResolver.update_auth_config(nil, %{data: %{}}, resolution)

      assert error_msg =~ "can't be blank"
    end

    test "does not update auth config and renders errors when public key is invalid", %{
      resolution: resolution
    } do
      assert {:error, error_msg} =
               ConfigResolver.update_auth_config(nil, %{data: @invalid_pubkey_attrs}, resolution)

      assert error_msg =~ "is not a valid PEM public key"
    end

    test "does not update auth config and renders errors when public key is malformed", %{
      resolution: resolution
    } do
      assert {:error, error_msg} =
               ConfigResolver.update_auth_config(
                 nil,
                 %{data: @malformed_pubkey_attrs},
                 resolution
               )

      assert error_msg =~ "is not a valid PEM public key"
    end

    test "updates and renders auth config when data is valid", %{resolution: resolution} do
      assert {:ok, "Auth config updated successfully"} =
               ConfigResolver.update_auth_config(nil, %{data: @update_attrs}, resolution)

      assert {:ok, %{jwt_public_key_pem: @new_pubkey}} =
               ConfigResolver.get_auth_config(nil, %{}, resolution)
    end
  end

  describe "get_device_registration_limit/3" do
    test "returns the device registration limit", %{
      resolution: resolution,
      realm_name: realm_name
    } do
      limit = 10
      Database.insert_device_registration_limit!(realm_name, limit)

      assert {:ok, ^limit} = ConfigResolver.get_device_registration_limit(nil, %{}, resolution)
    end
  end

  describe "get_datastream_maximum_storage_retention/3" do
    test "returns the datastream_maximum_storage_retention", %{
      resolution: resolution,
      realm_name: realm_name
    } do
      retention = 10
      Database.set_datastream_maximum_storage_retention(realm_name, retention)

      assert {:ok, ^retention} =
               ConfigResolver.get_datastream_maximum_storage_retention(nil, %{}, resolution)
    end
  end

  describe "missing context" do
    test "returns error when realm_name is missing" do
      resolution = %{context: %{}}

      assert {:error, "Missing realm context"} =
               ConfigResolver.get_auth_config(nil, %{}, resolution)

      assert {:error, "Missing realm context"} =
               ConfigResolver.update_auth_config(nil, %{data: %{}}, resolution)

      assert {:error, "Missing realm context"} =
               ConfigResolver.get_device_registration_limit(nil, %{}, resolution)

      assert {:error, "Missing realm context"} =
               ConfigResolver.get_datastream_maximum_storage_retention(nil, %{}, resolution)
    end
  end
end
