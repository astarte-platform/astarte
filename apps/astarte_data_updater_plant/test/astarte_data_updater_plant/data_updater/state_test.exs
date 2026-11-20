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

defmodule Astarte.DataUpdaterPlant.DataUpdater.StateTest do
  use ExUnit.Case, async: true

  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.HandshakeState
  alias Astarte.DataUpdaterPlant.DataUpdater.State
  alias COSE.Keys.Symmetric

  test "inspect/1 doesn't show the shared secret" do
    secret = :binary.copy(<<0xAB>>, 32)

    state = %State{
      realm: "realm",
      encrypted_endpoints_key: HandshakeState.restore(secret),
      shared_secret: %Symmetric{k: secret, alg: :aes_256_gcm}
    }

    inspected = inspect(state, limit: :infinity, printable_limit: :infinity)

    assert inspected =~ ~s(realm: "realm")
    refute inspected =~ inspect(secret)
    refute inspected =~ "shared_secret"
    refute inspected =~ "encrypted_endpoints_key"
  end
end
