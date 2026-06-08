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
# SPDX-License-Identifier: Apache-2.0
#

defmodule Astarte.Cases.Triggers do
  @moduledoc """
  This module defines the setup for tests requiring access to the application
  database.

  You may define functions here to be used as helpers in your tests.
  """

  use ExUnit.CaseTemplate
  use Mimic

  alias Astarte.RPC.Triggers

  setup do
    test_process = self()

    Triggers
    |> stub(:notify_deletion, fn _realm_name, trigger_id, trigger ->
      send(test_process, {:trigger_deleted, trigger_id, trigger})
      :ok
    end)
    |> stub(:notify_installation, fn _realm_name, trigger, target, policy ->
      send(test_process, {:trigger_installed, trigger, target, policy})
      :ok
    end)

    :ok
  end
end
