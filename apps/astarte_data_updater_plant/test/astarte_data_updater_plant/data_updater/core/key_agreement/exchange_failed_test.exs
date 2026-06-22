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

  describe "new/1" do
    test "creates a struct with a valid reason" do
      assert ExchangeFailed.new(:hash_mismatch).reason == :hash_mismatch
      assert ExchangeFailed.new(:invalid_payload).reason == :invalid_payload
      assert ExchangeFailed.new(:unspecified).reason == :unspecified
    end

    test "raises for unknown atoms" do
      assert_raise ArgumentError, fn ->
        ExchangeFailed.new(:some_random_internal_error)
      end

      assert_raise ArgumentError, fn ->
        ExchangeFailed.new(:key_type_mismatch)
      end
    end
  end

  describe "cbor_encode/1 and cbor_decode/1 round-trip" do
    test "round-trips successfully for all valid reasons" do
      for reason <- [:hash_mismatch, :invalid_payload, :unspecified] do
        original = ExchangeFailed.new(reason)

        assert {:ok, decoded} =
                 original
                 |> ExchangeFailed.cbor_encode()
                 |> ExchangeFailed.cbor_decode()

        assert decoded.reason == reason
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
    end

    test "returns error when reason code is negative" do
      assert {:error, :invalid_payload} = ExchangeFailed.cbor_decode(CBOR.encode([-1]))
    end

    test "returns error when reason is not an integer" do
      assert {:error, :invalid_payload} = ExchangeFailed.cbor_decode(CBOR.encode(["error"]))
    end

    test "returns error for an unrecognized reason code" do
      payload = CBOR.encode([99])

      assert {:error, :invalid_payload} = ExchangeFailed.cbor_decode(payload)
    end
  end

  describe "encode/1" do
    test "returns a one-element list with the correctly mapped integer code" do
      assert ExchangeFailed.encode(ExchangeFailed.new(:unspecified)) == [0]
      assert ExchangeFailed.encode(ExchangeFailed.new(:hash_mismatch)) == [1]
      assert ExchangeFailed.encode(ExchangeFailed.new(:invalid_payload)) == [2]
    end
  end
end
