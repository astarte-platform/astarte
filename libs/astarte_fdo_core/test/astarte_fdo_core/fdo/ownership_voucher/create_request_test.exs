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

defmodule Astarte.FDO.Core.OwnershipVoucher.CreateRequestTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.OwnershipVoucher.CreateRequest
  import Astarte.FDO.Core.Helpers

  @valid_params %{
    "ownership_voucher" => sample_voucher(),
    "private_key" => sample_private_key()
  }

  defp apply_changeset(params) do
    %CreateRequest{}
    |> CreateRequest.changeset(params)
    |> Ecto.Changeset.apply_action(:insert)
  end

  describe "changeset/2 with valid params" do
    test "populates device_guid" do
      expected_guid = sample_device_guid()

      assert {:ok, %CreateRequest{device_guid: ^expected_guid}} =
               apply_changeset(@valid_params)
    end

    test "populates cbor_ownership_voucher as the base64-decoded voucher body" do
      expected_cbor =
        sample_voucher()
        |> String.replace("-----BEGIN OWNERSHIP VOUCHER-----", "")
        |> String.replace("-----END OWNERSHIP VOUCHER-----", "")
        |> String.replace(~r/\s/, "")
        |> Base.decode64!()

      assert {:ok, %CreateRequest{cbor_ownership_voucher: ^expected_cbor}} =
               apply_changeset(@valid_params)
    end

    test "populates decoded_ownership_voucher consistent with cbor_ownership_voucher" do
      assert {:ok,
              %CreateRequest{
                cbor_ownership_voucher: cbor,
                decoded_ownership_voucher: decoded
              }} = apply_changeset(@valid_params)

      assert CBOR.encode(decoded) == cbor
    end

    test "populates extracted_private_key as a COSE ECC struct for an EC key" do
      assert {:ok, %CreateRequest{extracted_private_key: key}} = apply_changeset(@valid_params)
      assert is_struct(key, COSE.Keys.ECC)
    end

    test "populates extracted_private_key as a COSE RSA struct for an RSA key" do
      params = Map.put(@valid_params, "private_key", sample_rsa_private_key())
      assert {:ok, %CreateRequest{extracted_private_key: key}} = apply_changeset(params)
      assert is_struct(key, COSE.Keys.RSA)
    end
  end

  describe "changeset/2 with invalid params" do
    test "returns errors when required fields are missing" do
      assert {:error, changeset} = apply_changeset(%{})
      assert %{ownership_voucher: _, private_key: _} = errors_on(changeset)
    end

    test "returns error on :ownership_voucher for an empty string" do
      params = Map.put(@valid_params, "ownership_voucher", "")
      assert {:error, changeset} = apply_changeset(params)
      assert %{ownership_voucher: _} = errors_on(changeset)
    end

    test "returns error on :ownership_voucher for non-CBOR base64 content" do
      invalid_voucher = """
      -----BEGIN OWNERSHIP VOUCHER-----
      * not valid base64 *
      -----END OWNERSHIP VOUCHER-----
      """

      params = Map.put(@valid_params, "ownership_voucher", invalid_voucher)
      assert {:error, changeset} = apply_changeset(params)
      assert %{ownership_voucher: _} = errors_on(changeset)
    end

    test "returns error on :private_key for an invalid key PEM" do
      params = Map.put(@valid_params, "private_key", "")
      assert {:error, changeset} = apply_changeset(params)
      assert %{private_key: _} = errors_on(changeset)
    end
  end

  defp errors_on(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
