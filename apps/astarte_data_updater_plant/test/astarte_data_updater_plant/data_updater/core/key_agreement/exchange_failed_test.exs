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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.ExchangeFailedTest do
  use ExUnit.Case, async: true

  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.ExchangeFailed

  describe "new/3" do
    test "creates a struct with a valid reason" do
      assert {:ok, msg} = ExchangeFailed.new(0, :hash_mismatch, "hash did not match")
      assert msg.seq_num == 0
      assert msg.reason == :hash_mismatch
      assert msg.error_msg == "hash did not match"

      assert {:ok, %{reason: :invalid_argument}} =
               ExchangeFailed.new(1, :invalid_argument, "bad key")

      assert {:ok, %{reason: :internal_server_error}} =
               ExchangeFailed.new(2, :internal_server_error, "crash")

      assert {:ok, %{reason: :unprocessable_entity}} =
               ExchangeFailed.new(3, :unprocessable_entity, "key mismatch")
    end

    test "returns {:error, :invalid_reason} for unknown atoms" do
      for reason <- [:some_random_internal_error, :key_type_mismatch] do
        assert {:error, :invalid_reason} = ExchangeFailed.new(0, reason, "msg")
      end
    end
  end

  describe "cbor_encode/1 and cbor_decode/1 round-trip" do
    test "round-trips successfully for all valid reasons" do
      for reason <- [
            :hash_mismatch,
            :invalid_argument,
            :internal_server_error,
            :unprocessable_entity
          ] do
        assert {:ok, original} = ExchangeFailed.new(1, reason, "some context")

        assert {:ok, decoded} =
                 original
                 |> ExchangeFailed.cbor_encode()
                 |> ExchangeFailed.cbor_decode()

        assert decoded.seq_num == 1
        assert decoded.reason == reason
        assert decoded.error_msg == "some context"
      end
    end
  end

  describe "cbor_decode/1 error cases" do
    test "returns error for non-CBOR binary" do
      assert {:error, :invalid_payload} = ExchangeFailed.cbor_decode(<<0xFF, 0xFE>>)
    end

    test "returns error for wrong number of fields" do
      assert {:error, :invalid_payload} = ExchangeFailed.cbor_decode(CBOR.encode([]))
      assert {:error, :invalid_payload} = ExchangeFailed.cbor_decode(CBOR.encode([1, 2]))

      assert {:error, :invalid_payload} =
               ExchangeFailed.cbor_decode(CBOR.encode([1, 400, "msg", :extra]))
    end

    test "returns error when seq_num is negative" do
      assert {:error, :invalid_payload} = ExchangeFailed.cbor_decode(CBOR.encode([-1, 0, "msg"]))
    end

    test "returns error when error_code is negative" do
      assert {:error, :invalid_payload} = ExchangeFailed.cbor_decode(CBOR.encode([0, -1, "msg"]))
    end

    test "returns error when error_msg is not a string" do
      assert {:error, :invalid_payload} = ExchangeFailed.cbor_decode(CBOR.encode([0, 0, 42]))
    end

    test "decodes error code 3 as :unprocessable_entity" do
      payload = CBOR.encode([5, 3, "unsupported algorithm"])

      assert {:ok,
              %ExchangeFailed{
                seq_num: 5,
                reason: :unprocessable_entity,
                error_msg: "unsupported algorithm"
              }} =
               ExchangeFailed.cbor_decode(payload)
    end

    test "returns error for an unrecognized error code" do
      payload = CBOR.encode([0, 99, "unknown"])

      assert {:error, :invalid_payload} = ExchangeFailed.cbor_decode(payload)
    end
  end

  describe "encode/1" do
    test "returns a three-element list [seq_num, code, error_msg]" do
      assert {:ok, exchange_failed} = ExchangeFailed.new(0, :internal_server_error, "crash")
      assert ExchangeFailed.encode(exchange_failed) == [0, 0, "crash"]

      assert {:ok, exchange_failed} = ExchangeFailed.new(1, :invalid_argument, "bad key")
      assert ExchangeFailed.encode(exchange_failed) == [1, 1, "bad key"]

      assert {:ok, exchange_failed} = ExchangeFailed.new(2, :hash_mismatch, "mismatch")
      assert ExchangeFailed.encode(exchange_failed) == [2, 2, "mismatch"]

      assert {:ok, exchange_failed} = ExchangeFailed.new(3, :unprocessable_entity, "bad alg")
      assert ExchangeFailed.encode(exchange_failed) == [3, 3, "bad alg"]
    end
  end
end
