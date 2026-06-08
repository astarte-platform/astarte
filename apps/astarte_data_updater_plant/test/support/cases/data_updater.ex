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

defmodule Astarte.Cases.DataUpdater do
  @moduledoc """
  Setup the Mississippi Data Updater process so that it is available to tests.
  """

  use ExUnit.CaseTemplate
  use Mimic

  import Astarte.Helpers.DataUpdater

  alias Astarte.Core.Device

  using do
    quote do
      import Astarte.Helpers.DataUpdater
    end
  end

  setup_all context do
    %{realm_name: realm_name, device_id: device_id} = context
    encoded_device_id = Device.encode_device_id(device_id)

    data_updater = setup_data_updater(realm_name, device_id)
    state = dump_state(realm_name, encoded_device_id)

    %{data_updater: data_updater, state: state}
  end

  setup context do
    %{data_updater: data_updater} = context

    allow_data_updater(data_updater)
    :ok
  end
end
