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

defmodule Astarte.FDO.Core.OwnershipVoucher.CoreTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.OwnershipVoucher.Core
  alias Astarte.FDO.Core.PublicKey
  import Astarte.FDO.Core.FDOHelpers

  describe "binary_voucher/1" do
    test "returns ok with binary when given a valid certificate" do
      assert {:ok, binary} = Core.binary_voucher(sample_voucher())
      assert is_binary(binary)
    end

    test "returned binary is the base64-decoded voucher body" do
      expected =
        sample_voucher()
        |> String.replace("-----BEGIN OWNERSHIP VOUCHER-----", "")
        |> String.replace("-----END OWNERSHIP VOUCHER-----", "")
        |> String.replace(~r/\s/, "")
        |> Base.decode64!()

      assert {:ok, ^expected} = Core.binary_voucher(sample_voucher())
    end

    test "returns error when certificate has no PEM markers" do
      assert {:error, :invalid_certificate} = Core.binary_voucher("not a certificate")
    end

    test "returns error when certificate body is not valid base64" do
      bad_cert = """
      -----BEGIN OWNERSHIP VOUCHER-----
      !!!invalid-base64!!!
      -----END OWNERSHIP VOUCHER-----
      """

      assert {:error, :invalid_certificate} = Core.binary_voucher(bad_cert)
    end
  end

  describe "decode_ownership_voucher/1" do
    test "returns ok with a list for a valid voucher" do
      assert {:ok, decoded} = Core.decode_ownership_voucher(sample_voucher())
      assert is_list(decoded)
    end

    test "returns error for an invalid certificate" do
      assert {:error, :invalid_certificate} =
               Core.decode_ownership_voucher("not a voucher")
    end
  end

  describe "device_guid/1" do
    setup do
      {:ok, decoded} = Core.decode_ownership_voucher(sample_voucher())
      %{decoded: decoded}
    end

    test "returns ok with binary GUID", %{decoded: decoded} do
      assert {:ok, guid} = Core.device_guid(decoded)
      assert is_binary(guid)
    end

    test "returns the expected device GUID", %{decoded: decoded} do
      assert {:ok, guid} = Core.device_guid(decoded)
      assert guid == sample_device_guid()
    end

    test "returns error for an empty list" do
      assert :error = Core.device_guid([])
    end

    test "returns error for a malformed voucher list" do
      assert :error = Core.device_guid(["bad", "data"])
    end
  end

  describe "entry_public_key/1" do
    setup do
      {:ok, decoded} = Core.decode_ownership_voucher(sample_voucher())
      entry_array = Enum.at(decoded, 4)
      %{entry: List.first(entry_array)}
    end

    test "returns ok with a PublicKey struct for a valid entry", %{entry: entry} do
      assert {:ok, %PublicKey{}} = Core.entry_public_key(entry)
    end

    test "returns a secp256r1 key for the sample voucher entry", %{entry: entry} do
      assert {:ok, %PublicKey{type: :secp256r1}} = Core.entry_public_key(entry)
    end

    test "returns an x509-encoded public key", %{entry: entry} do
      assert {:ok, %PublicKey{encoding: :x509, body: body}} = Core.entry_public_key(entry)
      assert is_binary(body)
    end

    test "returns error for a plain binary that is not a COSE Sign1" do
      assert :error = Core.entry_public_key(<<1, 2, 3>>)
    end

    test "returns error for a non-binary value" do
      assert :error = Core.entry_public_key("not an entry")
    end
  end
end
