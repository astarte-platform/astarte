# Copyright 2017-2020 SECO Mind Srl
#
# SPDX-License-Identifier: Apache-2.0

#
# This file is part of Astarte.
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

defmodule AstarteE2E.Config.AstarteDeviceID do
  use Skogsra.Type
  alias Astarte.Core.Device

  require Logger

  @impl Skogsra.Type
  def cast(encoded_device_id) do
    case Device.decode_device_id(encoded_device_id) do
      {:ok, _device_id} ->
        {:ok, encoded_device_id}

      _ ->
        Logger.error("Invalid device ID.", tag: "invalid_device_id")
        :error
    end
  end
end
