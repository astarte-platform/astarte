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

  describe "to_cbor_list/1" do
    test "returns [entry_num, ov_entry]" do
      ov_entry = :crypto.strong_rand_bytes(64)

      msg = %OVNextEntry{
        entry_num: 3,
        ov_entry: ov_entry
      }

      assert [3, ^ov_entry] = OVNextEntry.to_cbor_list(msg)
    end
  end

  describe "encode/1" do
    test "encodes OVNextEntry as CBOR binary" do
      ov_entry = :crypto.strong_rand_bytes(64)

      msg = %OVNextEntry{
        entry_num: 0,
        ov_entry: ov_entry
      }

      cbor = OVNextEntry.encode(msg)
      assert is_binary(cbor)
      assert {:ok, [0, ^ov_entry], ""} = CBOR.decode(cbor)
    end
  end
end
