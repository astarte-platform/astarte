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

defmodule Astarte.Pairing.FDO.Rendezvous.CoreTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.Rendezvous.Core
  alias Astarte.Pairing.FDO.Rendezvous.RvTO2Addr

  import Astarte.Helpers.FDO

  describe "get_body_nonce/1" do
    setup do
      nonce = <<32, 54, 127, 243, 66, 48, 228, 115, 59, 186, 230, 246, 198, 179, 113, 78>>
      nonce_with_invalid_size = <<1, 2, 3, 4, 5, 6, 7, 8>>

      cbor =
        CBOR.encode([
          %CBOR.Tag{
            tag: :bytes,
            value: <<32, 54, 127, 243, 66, 48, 228, 115, 59, 186, 230, 246, 198, 179, 113, 78>>
          },
          %CBOR.Tag{
            tag: :bytes,
            value: <<32, 54, 127, 243, 66, 48, 228, 115, 59, 186, 230, 246, 198, 179, 113, 78>>
          }
        ])

      %{nonce: nonce, nonce_with_invalid_size: nonce_with_invalid_size, not_hello_ack_cbor: cbor}
    end

    test "returns nonce for actual FDO HelloAck CBOR payload (binary nonce)", %{nonce: nonce} do
      ack = hello_ack(nonce)
      assert {:ok, ^nonce} = Core.get_body_nonce(ack)
    end

    test "fails with wrong length CBOR body", %{nonce_with_invalid_size: nonce_with_invalid_size} do
      invalid_ack = hello_ack(nonce_with_invalid_size)
      assert {:error, :unexpected_nonce_size} == Core.get_body_nonce(invalid_ack)
    end

    test "only decodes valid cbor binaries" do
      assert {:error, :cbor_decode_error} == Core.get_body_nonce(<<>>)
    end

    test "fails for cbors with unexpected format", %{not_hello_ack_cbor: cbor} do
      assert {:error, :unexpected_body_format} == Core.get_body_nonce(cbor)
    end
  end

  describe "build_owner_sign_message/4" do
    setup do
      nonce = <<32, 54, 127, 243, 66, 48, 228, 115, 59, 186, 230, 246, 198, 179, 113, 78>>
      owner_key = sample_extracted_rsa_private_key()
      ownership_voucher = sample_voucher()
      addr_entries = [RvTO2Addr.for_realm("test1")]

      %{
        nonce: nonce,
        owner_key: owner_key,
        ownership_voucher: ownership_voucher,
        addr_entries: addr_entries
      }
    end

    test "returns TO0.OwnerSign message when given valid inputs",
         %{
           nonce: nonce,
           owner_key: owner_key,
           ownership_voucher: ownership_voucher,
           addr_entries: addr_entries
         } do
      to0_owner_sign_msg =
        Core.build_owner_sign_message(ownership_voucher, owner_key, nonce, addr_entries, 3600)

      {:ok, decoded_msg, _} = CBOR.decode(to0_owner_sign_msg)

      assert is_list(decoded_msg)
      assert is_binary(to0_owner_sign_msg)
    end
  end
end
