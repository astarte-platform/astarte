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

defmodule Astarte.FDO.OwnerOnboarding.SessionTokenTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.OwnerOnboarding.SessionToken

  describe "generate/2 and verify/1" do
    test "generated token can be verified and returns the original guid and nonce" do
      guid = "test-guid-1234"
      nonce = :crypto.strong_rand_bytes(16)

      token = SessionToken.generate(guid, nonce)

      assert is_binary(token)
      assert {:ok, ^guid, ^nonce} = SessionToken.verify(token)
    end

    test "verify returns error for a tampered token" do
      assert {:error, :invalid} = SessionToken.verify("not_a_valid_token")
    end

    test "verify returns error for an empty string" do
      assert {:error, _reason} = SessionToken.verify("")
    end
  end
end
