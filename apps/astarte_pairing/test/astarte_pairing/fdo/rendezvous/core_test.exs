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

  describe "get_rv_to2_addr_entries/0" do
    test "returns a list of entries with correct types" do
      {:ok, entries} = Core.get_rv_to2_addr_entries("test1", "test2")
      assert is_list(entries)
      assert length(entries) >= 1

      Enum.each(entries, fn entry ->
        assert is_binary(entry)
        {:ok, [decoded], _rest} = CBOR.decode(entry)
        assert is_list(decoded)
        assert length(decoded) == 4
        assert is_binary(Enum.at(decoded, 0))
        assert is_binary(Enum.at(decoded, 1))
        assert is_integer(Enum.at(decoded, 2))
        assert is_integer(Enum.at(decoded, 3))
      end)
    end
  end

  describe "build_cose_sign1/2" do
    setup do
      payload = CBOR.encode(["test", 123])
      {:ok, owner_key} = get_mock_owner_key()
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

    test "returns {:error, :signing_error} when passed invalid PEM key" do
      payload = CBOR.encode(["test", 123])
      invalid_key = "pippo"

      {:error, :signing_error} = Core.build_cose_sign1(payload, invalid_key)
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
      {:ok, owner_key} = get_mock_owner_key()
      {:ok, ownership_voucher} = get_mock_ownership_voucher()
      {:ok, addr_entries} = Core.get_rv_to2_addr_entries("test1", "test2")

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
      {:ok, to0_owner_sign_msg} =
        Core.build_owner_sign_message(ownership_voucher, owner_key, nonce, addr_entries)

      {:ok, decoded_msg, _} = CBOR.decode(to0_owner_sign_msg)

      assert is_list(decoded_msg)
      assert is_binary(to0_owner_sign_msg)
    end

    test "returns error when given invalid inputs",
         %{
           nonce: nonce,
           ownership_voucher: ownership_voucher,
           addr_entries: addr_entries
         } do
      assert {:error, _} =
               Core.build_owner_sign_message(ownership_voucher, "", nonce, addr_entries)
    end
  end

  defp assert_cose_sign1(payload, owner_key) do
    {:ok, %CBOR.Tag{tag: @cose_sign1_tag, value: cose_sign1_array}} =
      Core.build_cose_sign1(payload, owner_key)

    cose_sign1_array
  end

  defp hello_ack(nonce) do
    CBOR.encode([%CBOR.Tag{tag: :bytes, value: nonce}])
  end

  defp get_mock_ownership_voucher do
    ownership_voucher = """
    -----BEGIN OWNERSHIP VOUCHER-----
    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
    uliN+61J1dB0nA==
    -----END OWNERSHIP VOUCHER-----
    """

    {:ok, ownership_voucher}
  end

  defp get_mock_owner_key do
    owner_key = """
    -----BEGIN EC PRIVATE KEY-----
    MHcCAQEEIFlbTEE1Ce+RSqhU8FqxsY7eNb9BaBWOTw6qFv7l0DZtoAoGCCqGSM49
    AwEHoUQDQgAEocPEIHIrn08VRO5zkkDztwp72Sw0BSm0mZeLgOKkHLUPdVFFlc0E
    O82b1/S2Cwzwh8MIDDx0CN2b+IBl5bRwOw==
    -----END EC PRIVATE KEY-----
    """

    {:ok, owner_key}
  end
end
