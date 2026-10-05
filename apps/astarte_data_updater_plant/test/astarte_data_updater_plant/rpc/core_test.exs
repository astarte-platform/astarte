#
# This file is part of Astarte.
#
# Copyright 2025 - 2026 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.RPC.CoreTest do
  @moduledoc false
  alias Astarte.DataUpdaterPlant.DataUpdater.Impl
  alias Astarte.DataUpdaterPlant.RPC.Server.Core

  use Astarte.DataUpdaterPlant.Cases.Data, async: true
  use Astarte.DataUpdaterPlant.Cases.Trigger
  use Astarte.DataUpdaterPlant.Cases.Device
  use Astarte.DataUpdaterPlant.Cases.DataUpdater
  use ExUnitProperties

  use Mimic

  test "start_device_deletion/3 calls the `data_updater` server", context do
    %{realm_name: realm_name, device: device} = context
    encoded_device_id = device.encoded_id
    timestamp = DateTime.utc_now() |> DateTime.to_unix(:microsecond) |> Kernel.*(10)
    expected_signal = {:start_device_deletion, timestamp}

    Impl
    |> expect(:handle_signal, fn ^expected_signal, state -> {:ok, state} end)

    assert :ok = Core.start_device_deletion(realm_name, encoded_device_id, timestamp)
  end
end
