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

defmodule Astarte.FDO.Core.OwnerOnboarding.Done2Test do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.OwnerOnboarding.Done2

  describe "encode/1" do
    test "encodes to a CBOR binary" do
      nonce = :crypto.strong_rand_bytes(16)
      done2 = %Done2{nonce_to2_setup_dv: nonce}

      binary = Done2.encode(done2)

      assert is_binary(binary)
      assert {:ok, [%CBOR.Tag{tag: :bytes, value: ^nonce}], ""} = CBOR.decode(binary)
    end
  end

  describe "to_cbor_list/1" do
    test "returns a single-element list with byte-tagged nonce" do
      nonce = :crypto.strong_rand_bytes(16)
      done2 = %Done2{nonce_to2_setup_dv: nonce}

      assert [%CBOR.Tag{tag: :bytes, value: ^nonce}] = Done2.to_cbor_list(done2)
    end
  end
end
