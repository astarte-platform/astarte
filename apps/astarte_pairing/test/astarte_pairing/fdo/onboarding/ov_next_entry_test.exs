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

  alias Astarte.Pairing.FDO.OwnershipVoucher.Core

  import Astarte.Helpers.FDO

  describe "get_ov_entry/2" do
    test "returns {:ok, cbor_binary} when entry_num is valid" do
      {:ok, voucher} = sample_voucher() |> Core.decode_ownership_voucher()
      ov_entries = Enum.at(voucher, 3)

      assert length(ov_entries) > 0

      entry_num = 0
      expected_entry = Enum.at(ov_entries, entry_num)

      assert {:ok, encoded} = Core.get_ov_entry(voucher, entry_num)

      assert {:ok, [^entry_num, ^expected_entry], ""} = CBOR.decode(encoded)
    end

    test "returns {:ok, cbor_binary} when entry_num is valid and is the last entry" do
      {:ok, voucher} = sample_voucher() |> Core.decode_ownership_voucher()
      ov_entries = Enum.at(voucher, 3)

      assert length(ov_entries) > 0

      entry_num = length(ov_entries) - 1
      expected_entry = Enum.at(ov_entries, entry_num)

      assert {:ok, encoded} = Core.get_ov_entry(voucher, entry_num)

      assert {:ok, [^entry_num, ^expected_entry], ""} = CBOR.decode(encoded)
    end

    test "returns error for negative entry_num" do
      {:ok, voucher} = sample_voucher() |> Core.decode_ownership_voucher()

      assert {:error, "invalid_entry_number"} =
               Core.get_ov_entry(voucher, -1)
    end

    test "returns error when entry_num is over the max number ov entries" do
      {:ok, voucher} = sample_voucher() |> Core.decode_ownership_voucher()
      ov_entries = Enum.at(voucher, 3)
      invalid_index = length(ov_entries)

      assert {:error, "invalid_entry_number"} =
               Core.get_ov_entry(voucher, invalid_index)
    end
  end
end
