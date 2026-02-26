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
defmodule Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RendezvousInstrTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RendezvousInstr

  @rendezvous_info_instruction [5, %CBOR.Tag{tag: :bytes, value: "ufdo.astarte.localhost"}]

  describe "decode/1" do
    test "returns proper struct" do
      {:ok, instruction} = RendezvousInstr.decode(@rendezvous_info_instruction)

      assert %RendezvousInstr{} = instruction
    end

    test "decodes RVVariable" do
      {:ok, instruction} = RendezvousInstr.decode(@rendezvous_info_instruction)

      assert %RendezvousInstr{
               rv_variable: :dns
             } = instruction
    end

    test "decodes RVValue" do
      {:ok, instruction} = RendezvousInstr.decode(@rendezvous_info_instruction)

      assert %RendezvousInstr{
               rv_value: "ufdo.astarte.localhost"
             } = instruction
    end

    test "returns error for invalid RVVariable" do
      invalid_instruction = [100, %CBOR.Tag{tag: :bytes, value: "ufdo.astarte.localhost"}]
      assert :error = RendezvousInstr.decode(invalid_instruction)
    end

    test "returns error for invalid RVValue" do
      invalid_instruction = [5, "invalid value"]
      assert :error = RendezvousInstr.decode(invalid_instruction)
    end
  end
end
