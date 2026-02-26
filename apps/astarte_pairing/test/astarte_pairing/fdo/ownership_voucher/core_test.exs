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

defmodule Astarte.Pairing.FDO.OwnershipVoucher.CoreTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.Pairing.FDO.OwnershipVoucher.Core

  import Astarte.Helpers.FDO

  @decoded_voucher sample_voucher() |> Core.decode_ownership_voucher() |> elem(1)

  setup :verify_on_exit!

  describe "device_guid/1" do
    test "returns the device_id for a valid decoded ownership voucher" do
      assert {:ok, device_id} = Core.device_guid(@decoded_voucher)
      assert device_id == sample_device_guid()
    end

    test "returns error for invalid ownership vouchers" do
      assert :error == Core.device_guid([])
    end

    test "returns error for invalid header tags" do
      [_, %CBOR.Tag{value: encoded_header_tag} | _] = @decoded_voucher
      {:ok, header_tag, _rest} = CBOR.decode(encoded_header_tag)
      invalid_header_tag = header_tag |> List.replace_at(1, <<>>) |> CBOR.encode()
      invalid_voucher = @decoded_voucher |> List.replace_at(1, invalid_header_tag)

      assert :error == Core.device_guid(invalid_voucher)
    end
  end

  describe "binary_voucher/1" do
    test "returns cbor encoded voucher" do
      assert {:ok, binary_voucher} = Core.binary_voucher(sample_voucher())
      assert {:ok, _, _} = CBOR.decode(binary_voucher)
    end

    test "rejects invalid certificates" do
      invalid_cert = ""
      assert {:error, :invalid_certificate} = Core.binary_voucher(invalid_cert)
    end

    test "rejects non base64 encoded certificates" do
      invalid_cert = """
      -----BEGIN OWNERSHIP VOUCHER-----
      * not a valid base64 *
      -----END OWNERSHIP VOUCHER-----
      """

      assert {:error, _} = Core.binary_voucher(invalid_cert)
    end
  end

  describe "decode_ownership_voucher/1" do
    test "returns the decoded voucher if binary_voucher/1 returns a valid cbor" do
      voucher = ""
      cbor = CBOR.encode([])

      expect(Core, :binary_voucher, fn ^voucher -> {:ok, cbor} end)

      assert {:ok, decoded_voucher} = Core.decode_ownership_voucher(voucher)
      assert CBOR.encode(decoded_voucher) == cbor
    end
  end
end
