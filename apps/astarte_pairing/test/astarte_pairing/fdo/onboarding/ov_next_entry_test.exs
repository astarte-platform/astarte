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

defmodule Astarte.Pairing.FDO.Onboarding.OvNextEntryTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias Astarte.Pairing.FDO.OwnershipVoucher.Core

  import Astarte.Helpers.FDO

  describe "get_ov_entry/2" do
    setup do
      {:ok, voucher} = sample_voucher() |> Core.decode_ownership_voucher()
      {:ok, decoded_voucher} = OwnershipVoucher.decode(voucher)

      {:ok,
       %{
         voucher: decoded_voucher,
         entries: decoded_voucher.entries,
         count: length(decoded_voucher.entries)
       }}
    end

    test "returns {:ok, cbor_binary} when entry_num is valid", %{
      voucher: voucher,
      entries: ov_entries
    } do
      entry_num = 0
      expected_entry = Enum.at(ov_entries, entry_num)

      assert {:ok, encoded} = Core.get_ov_entry(voucher, entry_num)

      assert {:ok, [^entry_num, ^expected_entry], ""} = CBOR.decode(encoded)
    end

    test "returns {:ok, cbor_binary} when entry_num is valid and is the last entry", %{
      voucher: voucher,
      entries: ov_entries,
      count: count
    } do
      entry_num = count - 1
      expected_entry = Enum.at(ov_entries, entry_num)

      assert {:ok, encoded} = Core.get_ov_entry(voucher, entry_num)

      assert {:ok, [^entry_num, ^expected_entry], ""} = CBOR.decode(encoded)
    end

    test "returns error for negative entry_num", %{voucher: voucher} do
      assert {:error, "invalid_entry_number"} =
               Core.get_ov_entry(voucher, -1)
    end

    test "returns error when entry_num is over the max number ov entries", %{
      voucher: voucher,
      count: invalid_index
    } do
      assert {:error, "invalid_entry_number"} =
               Core.get_ov_entry(voucher, invalid_index)
    end
  end
end
