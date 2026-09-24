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

defmodule Astarte.FDO.Core.OwnerOnboarding.OVNextEntryTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.OwnerOnboarding.OVNextEntry

  @ov_entry_binary :crypto.strong_rand_bytes(32)

  @sample %OVNextEntry{
    entry_num: 0,
    ov_entry: @ov_entry_binary
  }

  describe "to_cbor_list/1" do
    test "returns a 2-element list with entry_num and ov_entry" do
      result = OVNextEntry.to_cbor_list(@sample)
      assert result == [0, @ov_entry_binary]
    end

    test "preserves entry_num" do
      entry = %OVNextEntry{entry_num: 3, ov_entry: <<1, 2, 3>>}
      [num, _] = OVNextEntry.to_cbor_list(entry)
      assert num == 3
    end
  end

  describe "encode/1" do
    test "returns a binary" do
      result = OVNextEntry.encode(@sample)
      assert is_binary(result)
    end

    test "roundtrips through CBOR decoding" do
      binary = OVNextEntry.encode(@sample)
      {:ok, [entry_num, ov_entry], ""} = CBOR.decode(binary)

      assert entry_num == @sample.entry_num
      assert ov_entry == @sample.ov_entry
    end

    test "encodes different entry_num values correctly" do
      for num <- [0, 1, 5, 255] do
        entry = %OVNextEntry{entry_num: num, ov_entry: <<0>>}
        binary = OVNextEntry.encode(entry)
        {:ok, [decoded_num, _], ""} = CBOR.decode(binary)
        assert decoded_num == num
      end
    end
  end
end
