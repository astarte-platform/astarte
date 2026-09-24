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

defmodule Astarte.FDO.Core.OwnerOnboarding.GetOVNextEntryTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.OwnerOnboarding.GetOVNextEntry

  describe "decode/1" do
    test "decodes entry_num = 0" do
      cbor = CBOR.encode([0])
      assert {:ok, %GetOVNextEntry{entry_num: 0}} = GetOVNextEntry.decode(cbor)
    end

    test "decodes entry_num = 5" do
      cbor = CBOR.encode([5])
      assert {:ok, %GetOVNextEntry{entry_num: 5}} = GetOVNextEntry.decode(cbor)
    end

    test "returns error for invalid CBOR" do
      assert {:error, :message_body_error} = GetOVNextEntry.decode(<<0xFF>>)
    end

    test "returns error for negative entry_num" do
      cbor = CBOR.encode([-1])
      assert {:error, :message_body_error} = GetOVNextEntry.decode(cbor)
    end

    test "returns error for non-integer payload" do
      cbor = CBOR.encode(["not_an_integer"])
      assert {:error, :message_body_error} = GetOVNextEntry.decode(cbor)
    end

    test "returns error for wrong list format" do
      cbor = CBOR.encode([0, 1])
      assert {:error, :message_body_error} = GetOVNextEntry.decode(cbor)
    end
  end
end
