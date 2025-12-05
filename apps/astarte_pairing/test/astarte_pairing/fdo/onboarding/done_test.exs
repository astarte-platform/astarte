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

defmodule Astarte.Pairing.FDO.Onboarding.DoneTest do
  use ExUnit.Case, async: true

  alias Astarte.Pairing.FDO.OwnerOnboarding
  alias Astarte.DataAccess.FDO.TO2Session

  @correct_prove_dv_nonce :crypto.strong_rand_bytes(16)

  @wrong_prove_dv_nonce :crypto.strong_rand_bytes(16)

  @setup_dv_nonce :crypto.strong_rand_bytes(16)

  @minimal_to2_session %TO2Session{
    prove_dv_nonce: @correct_prove_dv_nonce,
    setup_dv_nonce: @setup_dv_nonce
  }

  describe "done/2" do
    test "returns {:ok, cbor_binary} (containing SetupDv nonce) when ProveDv nonces match" do
      done_msg = [%CBOR.Tag{tag: :bytes, value: @correct_prove_dv_nonce}]

      {:ok, done2_msg_cbor} = OwnerOnboarding.done(@minimal_to2_session, done_msg)

      assert {:ok, [%CBOR.Tag{tag: :bytes, value: @setup_dv_nonce}], _} =
               CBOR.decode(done2_msg_cbor)
    end

    test "returns {:error, TBD} when the ProveDv nonces don't match" do
      mismatch_msg = [%CBOR.Tag{tag: :bytes, value: @wrong_prove_dv_nonce}]

      {:error, :prove_dv_nonce_mismatch} =
        OwnerOnboarding.done(@minimal_to2_session, mismatch_msg)
    end
  end
end
