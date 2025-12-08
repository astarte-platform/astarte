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

defmodule Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RendezvousDirectiveTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RendezvousInstr
  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RendezvousDirective

  @rendezvous_info_instructions [
    [5, %CBOR.Tag{tag: :bytes, value: "ufdo.astarte.localhost"}],
    [12, %CBOR.Tag{tag: :bytes, value: <<1>>}]
  ]

  describe "decode/1" do
    test "returns proper struct" do
      {:ok, instructions} = RendezvousDirective.decode(@rendezvous_info_instructions)

      assert %RendezvousDirective{} = instructions
    end

    test "decode all instructions" do
      {:ok, instructions} = RendezvousDirective.decode(@rendezvous_info_instructions)

      assert %RendezvousDirective{
               instructions: [
                 %RendezvousInstr{rv_value: "ufdo.astarte.localhost", rv_variable: :dns},
                 %RendezvousInstr{rv_value: <<1>>, rv_variable: :protocol}
               ]
             } == instructions
    end

    test "returns error if decoding instruction fails" do
      invalid_instruction = [[100, %CBOR.Tag{tag: :bytes, value: "ufdo.astarte.localhost"}]]

      assert {:error, :invalid_ownership_voucher} ==
               RendezvousDirective.decode(invalid_instruction)
    end
  end

  describe "encode/1" do
    test "encodes from RendezvousDirective to raw" do
      {:ok, instructions} = RendezvousDirective.decode(@rendezvous_info_instructions)

      raw_instructions = RendezvousDirective.encode(instructions)

      assert raw_instructions == @rendezvous_info_instructions
    end
  end
end
