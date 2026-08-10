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

defmodule Astarte.VMQ.Plugin.Test.Cases.AMQP do
  @moduledoc "ExUnit case template that opens a shared AMQP channel for each test."
  use ExUnit.CaseTemplate

  alias Astarte.VMQ.Plugin.Test.Helpers.AMQP

  setup_all do
    channel = AMQP.setup_channel!()
    {:ok, chan: channel}
  end
end
