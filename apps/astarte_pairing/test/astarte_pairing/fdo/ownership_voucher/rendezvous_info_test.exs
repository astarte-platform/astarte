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

defmodule Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfoTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo

  @rendezvous_info_cbor [
    [
      [5, %CBOR.Tag{tag: :bytes, value: "ufdo.astarte.localhost"}],
      [12, %CBOR.Tag{tag: :bytes, value: <<1>>}],
      [3, %CBOR.Tag{tag: :bytes, value: <<24, 80>>}],
      [4, %CBOR.Tag{tag: :bytes, value: <<25, 31, 105>>}],
      [13, %CBOR.Tag{tag: :bytes, value: "\n"}]
    ]
  ]

  describe "decode/1" do
    test "returns RendezvousInfo struct" do
      {:ok, rv_info} = RendezvousInfo.decode(@rendezvous_info_cbor)

      assert %RendezvousInfo{} = rv_info
    end

    test "returns proper number of Rendezvous Directives" do
      {:ok, rv_info} = RendezvousInfo.decode(@rendezvous_info_cbor)

      assert length(rv_info.directives) == 1
    end

    test "returns proper number of Rendezvous Instructions" do
      {:ok, rv_info} = RendezvousInfo.decode(@rendezvous_info_cbor)
      [directive | _] = rv_info.directives
      assert length(directive.instructions) == 5
    end

    test "returns error for invalid Rendezvous Directives" do
      not_a_list = "invalid_directives"

      assert {:error, :invalid_ownership_voucher} =
               RendezvousInfo.decode(not_a_list)
    end

    test "returns error if decoding RVVariable fails" do
      rendezvous_info_invalid_var = [[[100, %CBOR.Tag{tag: :bytes, value: <<1>>}]]]

      assert {:error, :invalid_ownership_voucher} =
               RendezvousInfo.decode(rendezvous_info_invalid_var)
    end

    test "returns error if decoding RVValue fails" do
      rendezvous_info_invalid_value = [[[5, "invalid_value"]]]

      assert {:error, :invalid_ownership_voucher} =
               RendezvousInfo.decode(rendezvous_info_invalid_value)
    end
  end

  describe "encode/1" do
    test "encodes valid Rendezvous info" do
      {:ok, rv_info} = RendezvousInfo.decode(@rendezvous_info_cbor)

      raw_rv_info = RendezvousInfo.encode(rv_info)

      assert raw_rv_info == @rendezvous_info_cbor
    end
  end
end
