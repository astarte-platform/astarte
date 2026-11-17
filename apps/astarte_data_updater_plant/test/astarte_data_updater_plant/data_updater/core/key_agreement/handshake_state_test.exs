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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.HandshakeStateTest do
  use ExUnit.Case, async: true

  import ExUnit.CaptureLog

  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.HandshakeState
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.InitExchange

  setup do
    init_exchange = InitExchange.new(0)

    %{
      secret: :binary.copy(<<0xAB>>, 32),
      init_exchange: init_exchange,
      started:
        {:handshake_started, %{key_type: init_exchange.key_type, init_exchange: init_exchange}}
    }
  end

  describe "state_name/1" do
    test "returns the name of every state without its data", context do
      %{secret: secret, started: started} = context

      assert HandshakeState.state_name(:uninitialized) == :uninitialized
      assert HandshakeState.state_name(started) == :handshake_started
      assert HandshakeState.state_name(HandshakeState.restore(secret)) == :established
      assert HandshakeState.state_name({:failed, :invalid_argument}) == :failed
    end
  end

  describe "transition/2 with an invalid event" do
    test "doesn't log the shared secret held by the established state", %{secret: secret} do
      log =
        capture_log(fn ->
          assert {:error, :unprocessable_entity, "invalid transition"} =
                   HandshakeState.transition(
                     HandshakeState.restore(secret),
                     {:handshake_completed, secret}
                   )
        end)

      refute log =~ inspect(secret)
      refute log =~ "shared_secret"
    end

    test "doesn't log the shared secret carried by the event", %{secret: secret} do
      log =
        capture_log(fn ->
          assert {:error, :unprocessable_entity, "invalid transition"} =
                   HandshakeState.transition(:uninitialized, {:handshake_completed, secret})
        end)

      refute log =~ inspect(secret)
    end
  end
end
