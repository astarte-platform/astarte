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

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.HashOkTest do
  use ExUnit.Case, async: true

  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.HashOk

  describe "encode/1" do
    test "returns a single-element list with the seq_num" do
      assert HashOk.encode(%HashOk{seq_num: 0}) == [0]
      assert HashOk.encode(%HashOk{seq_num: 42}) == [42]
    end
  end

  describe "cbor_encode/1" do
    test "encodes the struct into a valid CBOR binary" do
      msg = %HashOk{seq_num: 7}
      encoded = HashOk.cbor_encode(msg)

      assert is_binary(encoded)
      assert {:ok, [7], ""} = CBOR.decode(encoded)
    end
  end

  describe "cbor_decode/1" do
    test "successfully decodes a valid CBOR payload to the seq_num it carries" do
      payload_zero = CBOR.encode([0])
      assert {:ok, %HashOk{seq_num: 0}} = HashOk.cbor_decode(payload_zero)

      payload_large = CBOR.encode([65_535])
      assert {:ok, %HashOk{seq_num: 65_535}} = HashOk.cbor_decode(payload_large)
    end

    test "returns error for valid CBOR with invalid inner structure" do
      invalid_payloads = [
        CBOR.encode("not a list"),
        CBOR.encode([]),
        CBOR.encode([-1]),
        CBOR.encode(["string"]),
        CBOR.encode([1, 2])
      ]

      for payload <- invalid_payloads do
        assert {:error, :invalid_argument, "invalid HashOk payload"} = HashOk.cbor_decode(payload)
      end
    end

    test "returns error for invalid malformed CBOR binary" do
      invalid_cbor = <<0xFF>>

      assert {:error, :invalid_argument, "invalid HashOk payload"} =
               HashOk.cbor_decode(invalid_cbor)
    end
  end

  describe "cbor_encode/1 and cbor_decode/1 round-trip" do
    test "round-trips successfully" do
      original = %HashOk{seq_num: 123}

      assert {:ok, decoded} = original |> HashOk.cbor_encode() |> HashOk.cbor_decode()
      assert decoded.seq_num == original.seq_num
    end

    test "round-trips with seq_num 0" do
      msg = %HashOk{seq_num: 0}
      assert {:ok, decoded} = msg |> HashOk.cbor_encode() |> HashOk.cbor_decode()
      assert decoded.seq_num == 0
    end
  end
end
