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

defmodule Astarte.Helpers.DataUpdater do
  alias Astarte.DataUpdaterPlant.DataUpdater
  import Mimic

  def setup_data_updater(realm_name, encoded_device_id) do
    {:ok, message_tracker} = DataUpdater.fetch_message_tracker(realm_name, encoded_device_id)

    {:ok, data_updater} =
      DataUpdater.fetch_data_updater_process(
        realm_name,
        encoded_device_id,
        message_tracker,
        true
      )

    Astarte.DataAccess.Config
    |> allow(self(), data_updater)

    :ok = GenServer.call(data_updater, :start)

    %{message_tracker: message_tracker}
  end
end
