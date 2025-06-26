#
# This file is part of Astarte.
#
# Copyright 2017-2025 SECO Mind Srl
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

defmodule Astarte.Pairing.Info do
  @moduledoc """
  The Info context.
  """

  alias Astarte.Pairing.Info.DeviceInfo
  alias Astarte.Pairing.Engine

  require Logger

  @doc """
  Retrieves device info.
  """
  def get_device_info(realm, hw_id, secret) do
    with {:ok, %{device_status: status, version: version, protocols: protocols}} <-
           Engine.get_info(realm, hw_id, secret) do
      device_info = %DeviceInfo{
        version: version,
        status: status,
        protocols: protocols
      }

      {:ok, device_info}
    end
  end
end
