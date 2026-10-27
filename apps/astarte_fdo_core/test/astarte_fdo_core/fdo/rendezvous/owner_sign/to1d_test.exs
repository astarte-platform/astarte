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

defmodule Astarte.FDO.Core.Rendezvous.OwnerSign.TO1DTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.Hash
  alias Astarte.FDO.Core.Rendezvous.OwnerSign.TO1D
  alias Astarte.FDO.Core.Rendezvous.RvTO2Addr
  alias COSE.Keys.ECC

  defp sample do
    %TO1D{
      rv_to2_addr: [
        %RvTO2Addr{ip: nil, dns: "owner.example.com", port: 8042, protocol: :https}
      ],
      to0d_hash: Hash.new(:sha256, "some-to0d-content")
    }
  end

  describe "encode/1" do
    test "returns a 2-element list" do
      result = TO1D.encode(sample())
      assert length(result) == 2
    end

    test "first element is a list of encoded rv_to2_addr" do
      [rv_list, _] = TO1D.encode(sample())
      assert is_list(rv_list)
      assert length(rv_list) == 1
    end

    test "second element is a hash encoding (2-element list)" do
      [_, hash_encoded] = TO1D.encode(sample())
      assert [_type_id, %CBOR.Tag{tag: :bytes}] = hash_encoded
    end
  end

  describe "encode_cbor/1" do
    test "returns a binary" do
      result = TO1D.encode_cbor(sample())
      assert is_binary(result)
    end

    test "decodes back to a 2-element list" do
      cbor = TO1D.encode_cbor(sample())
      {:ok, list, ""} = CBOR.decode(cbor)
      assert length(list) == 2
    end
  end

  describe "encode_sign/2" do
    test "returns {:ok, cbor_tag} with a valid key" do
      key = ECC.generate(:es256)
      assert {:ok, signed} = TO1D.encode_sign(sample(), key)
      assert %CBOR.Tag{} = signed
    end
  end
end
