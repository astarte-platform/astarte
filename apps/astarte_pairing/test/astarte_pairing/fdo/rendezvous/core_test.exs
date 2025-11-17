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

  import Astarte.Helpers.FDO

  @es256 -7
  @es256_identifier 1
  @cose_sign1_tag 18

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

  describe "get_rv_to2_addr_entry/2" do
    test "returns a list of entries with correct types and one element" do
      {:ok, entries} = Core.get_rv_to2_addr_entry("test1")
      assert is_list(entries)
      assert length(entries) == 1

      Enum.each(entries, fn entry ->
        assert is_binary(entry)
        {:ok, [decoded], _rest} = CBOR.decode(entry)
        assert is_list(decoded)
        assert length(decoded) == 4
        assert is_nil(Enum.at(decoded, 0))
        assert is_binary(Enum.at(decoded, 1))
        assert is_integer(Enum.at(decoded, 2))
        assert is_integer(Enum.at(decoded, 3))
      end)
    end

    test "add an entry to a list of entries, returns with correct types and one more entry" do
      {:ok, entries} = Core.get_rv_to2_addr_entry("test1")
      {:ok, entries} = Core.get_rv_to2_addr_entry("test2", entries)
      assert is_list(entries)
      assert length(entries) == 2

      Enum.each(entries, fn entry ->
        assert is_binary(entry)
        {:ok, [decoded], _rest} = CBOR.decode(entry)
        assert is_list(decoded)
        assert length(decoded) == 4
        assert is_nil(Enum.at(decoded, 0))
        assert is_binary(Enum.at(decoded, 1))
        assert is_integer(Enum.at(decoded, 2))
        assert is_integer(Enum.at(decoded, 3))
      end)
    end
  end

  describe "build_cose_sign1/2" do
    setup do
      payload = CBOR.encode(["test", 123])
      owner_key = sample_extracted_private_key()
      protected_header = %{@es256_identifier => @es256}
      protected_header_cbor = CBOR.encode(protected_header)

      %{payload: payload, owner_key: owner_key, protected_header_cbor: protected_header_cbor}
    end

    test "returns sign list for valid payload and owner key", %{
      payload: payload,
      owner_key: owner_key
    } do
      cose_sign1_array = assert_cose_sign1(payload, owner_key)

      assert is_list(cose_sign1_array)
      assert length(cose_sign1_array) == 4
    end

    test "returns sign with correct protected header for valid payload and owner key", %{
      payload: payload,
      owner_key: owner_key,
      protected_header_cbor: protected_header_cbor
    } do
      cose_sign1_array = assert_cose_sign1(payload, owner_key)

      assert List.pop_at(cose_sign1_array, 0) |> elem(0) == %CBOR.Tag{
               tag: :bytes,
               value: protected_header_cbor
             }
    end

    test "returns sign with correct unprotected header for valid payload and owner key", %{
      payload: payload,
      owner_key: owner_key
    } do
      cose_sign1_array = assert_cose_sign1(payload, owner_key)

      assert List.pop_at(cose_sign1_array, 1) |> elem(0) == %{}
    end

    test "returns sign with correct cbor payload for valid payload and owner key", %{
      payload: payload,
      owner_key: owner_key
    } do
      cose_sign1_array = assert_cose_sign1(payload, owner_key)

      assert List.pop_at(cose_sign1_array, 2) |> elem(0) == %CBOR.Tag{tag: :bytes, value: payload}
    end

    test "raises with an invalid PEM key" do
      payload = CBOR.encode(["test", 123])
      invalid_key = {:InvalidKey, <<>>}

      assert_raise ArgumentError, fn -> Core.build_cose_sign1(payload, invalid_key) end
    end

    test "returns sign with correct cbor signature for valid payload and owner key", %{
      payload: payload,
      owner_key: owner_key
    } do
      cose_sign1_array = assert_cose_sign1(payload, owner_key)

      signature_tag = List.pop_at(cose_sign1_array, 3) |> elem(0)
      assert %CBOR.Tag{tag: :bytes, value: signature_value} = signature_tag
      assert is_binary(signature_value)
    end
  end

  describe "build_owner_sign_message/4" do
    setup do
      nonce = <<32, 54, 127, 243, 66, 48, 228, 115, 59, 186, 230, 246, 198, 179, 113, 78>>
      owner_key = sample_extracted_rsa_private_key()
      ownership_voucher = sample_voucher()
      {:ok, addr_entries} = Core.get_rv_to2_addr_entry("test1")

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
        Core.build_owner_sign_message(ownership_voucher, owner_key, nonce, addr_entries)

      {:ok, decoded_msg, _} = CBOR.decode(to0_owner_sign_msg)

      assert is_list(decoded_msg)
      assert is_binary(to0_owner_sign_msg)
    end
  end

  defp assert_cose_sign1(payload, owner_key) do
    %CBOR.Tag{tag: @cose_sign1_tag, value: cose_sign1_array} =
      Core.build_cose_sign1(payload, owner_key)

    cose_sign1_array
  end
end
