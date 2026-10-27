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

defmodule Astarte.FDO.Core.Rendezvous.OwnerSign.TO0DTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.Rendezvous.OwnerSign.TO0D

  defp sample do
    %TO0D{
      cbor_decoded_ownership_voucher: [1, 2, 3],
      wait_seconds: 3600,
      nonce_to0_sign: :crypto.strong_rand_bytes(16)
    }
  end

  describe "encode/1" do
    test "returns a 3-element list" do
      result = TO0D.encode(sample())
      assert length(result) == 3
    end

    test "first element is the decoded ownership voucher" do
      t = sample()
      [ov, _, _] = TO0D.encode(t)
      assert ov == t.cbor_decoded_ownership_voucher
    end

    test "second element is wait_seconds" do
      t = sample()
      [_, wait, _] = TO0D.encode(t)
      assert wait == t.wait_seconds
    end

    test "nonce is wrapped as a CBOR bstr tag" do
      t = sample()
      [_, _, nonce_tagged] = TO0D.encode(t)
      assert %CBOR.Tag{tag: :bytes, value: nonce_val} = nonce_tagged
      assert nonce_val == t.nonce_to0_sign
    end
  end

  describe "encode_cbor/1" do
    test "returns a binary" do
      result = TO0D.encode_cbor(sample())
      assert is_binary(result)
    end

    test "CBOR decodes back to a 3-element list" do
      cbor = TO0D.encode_cbor(sample())
      {:ok, list, ""} = CBOR.decode(cbor)
      assert length(list) == 3
    end
  end
end
