#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.Fdo.OwnershipVoucher.CreateRequestTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.OwnershipVoucher.CreateRequest

  import Astarte.Helpers.FDO

  @sample_params %{
    "ownership_voucher" => sample_voucher(),
    "private_key" => sample_private_key()
  }

  describe "changeset/2 populates" do
    test "`device_guid` for a given ownership voucher" do
      expected_guid = sample_device_guid()
      assert %CreateRequest{device_guid: ^expected_guid} = from_changeset!(@sample_params)
    end

    test "`cbor_ownership_voucher` as the base64 decoded ownership voucher" do
      expected_cbor_voucher =
        sample_voucher()
        |> String.replace("-----BEGIN OWNERSHIP VOUCHER-----", "")
        |> String.replace("-----END OWNERSHIP VOUCHER-----", "")
        |> String.replace(~r/\s/, "")
        |> Base.decode64!()

      assert %CreateRequest{cbor_ownership_voucher: ^expected_cbor_voucher} =
               from_changeset!(@sample_params)
    end

    test "`decoded_ownership_voucher` as the cbor decoded `cbor_ownership_voucher`" do
      assert %CreateRequest{
               cbor_ownership_voucher: cbor_ownership_voucher,
               decoded_ownership_voucher: decoded_ownership_voucher
             } = from_changeset!(@sample_params)

      assert CBOR.encode(decoded_ownership_voucher) == cbor_ownership_voucher
    end

    test "`extracted_private_key` as the `:public_key.private_key()` encoding of the EC pem key" do
      assert %CreateRequest{extracted_private_key: extracted_private_key} =
               from_changeset!(@sample_params)

      assert elem(extracted_private_key, 0) == :ECPrivateKey
    end

    test "`extracted_private_key` as the `:public_key.private_key()` encoding of the RSA pem key" do
      params = Map.replace!(@sample_params, "private_key", sample_rsa_private_key())

      assert %CreateRequest{extracted_private_key: extracted_private_key} =
               from_changeset!(params)

      assert elem(extracted_private_key, 0) == :RSAPrivateKey
    end
  end

  describe "changeset/2 rejects" do
    test "non base64 encoded ownership vouchers" do
      invalid_voucher = ""
      params = Map.replace!(@sample_params, "ownership_voucher", invalid_voucher)

      assert {:error, _} = from_changeset(params)
    end

    test "base64 encodes of non-cbor ownership vouchers" do
      invalid_voucher = """
      -----BEGIN OWNERSHIP VOUCHER-----
      * not a valid base64 *
      -----END OWNERSHIP VOUCHER-----
      """

      params = Map.replace!(@sample_params, "ownership_voucher", invalid_voucher)

      assert {:error, _} = from_changeset(params)
    end

    test "invalid owner keys" do
      invalid_key = ""
      params = Map.replace!(@sample_params, "private_key", invalid_key)

      assert {:error, _} = from_changeset(params)
    end
  end

  defp from_changeset(params) do
    %CreateRequest{}
    |> CreateRequest.changeset(params)
    |> Ecto.Changeset.apply_action(:insert)
  end

  defp from_changeset!(params) do
    %CreateRequest{}
    |> CreateRequest.changeset(params)
    |> Ecto.Changeset.apply_action!(:insert)
  end
end
