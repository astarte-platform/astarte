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

defmodule Astarte.FDO.Core.OwnerOnboarding.DoneTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.OwnerOnboarding.Done

  describe "cbor_decode/1" do
    test "decodes a valid Done CBOR binary" do
      nonce = :crypto.strong_rand_bytes(16)
      cbor = CBOR.encode([%CBOR.Tag{tag: :bytes, value: nonce}])

      assert {:ok, %Done{nonce_to2_prove_dv: ^nonce}} = Done.cbor_decode(cbor)
    end

    test "returns error for invalid CBOR" do
      assert {:error, :message_body_error} = Done.cbor_decode(<<0xFF>>)
    end

    test "returns error for CBOR with wrong payload structure" do
      cbor = CBOR.encode([1, 2, 3])
      assert {:error, :message_body_error} = Done.cbor_decode(cbor)
    end

    test "returns error when nonce is not byte-tagged" do
      cbor = CBOR.encode(["not_a_byte_tag"])
      assert {:error, :message_body_error} = Done.cbor_decode(cbor)
    end
  end

  describe "decode/1" do
    test "decodes a valid CBOR list" do
      nonce = :crypto.strong_rand_bytes(16)
      payload = [%CBOR.Tag{tag: :bytes, value: nonce}]

      assert {:ok, %Done{nonce_to2_prove_dv: ^nonce}} = Done.decode(payload)
    end

    test "returns error for malformed list" do
      assert {:error, :message_body_error} = Done.decode(["wrong"])
    end
  end
end
