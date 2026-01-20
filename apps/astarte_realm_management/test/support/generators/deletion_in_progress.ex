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

defmodule Astarte.RealmManagement.Generators.DeletionInProgress do
  @moduledoc """
  Generator for `Astarte.DataAccess.Device.DeletionInProgress`
  """
  use ExUnitProperties

  import Astarte.Generators.Utilities.ParamsGen

  alias Astarte.DataAccess.Device.DeletionInProgress

  alias Astarte.Core.Generators.Device, as: DeviceGenerator

  @doc false
  @spec deletion_in_progress(params :: keyword()) :: StreamData.t(DeletionInProgress.t())
  def deletion_in_progress(params \\ []) do
    params gen all device_id <- DeviceGenerator.id(),
                   dup_end_ack <- boolean(),
                   vmq_ack <- boolean(),
                   dup_start_ack <- boolean(),
                   params: params do
      %DeletionInProgress{
        device_id: device_id,
        dup_end_ack: dup_end_ack,
        dup_start_ack: dup_start_ack,
        vmq_ack: vmq_ack
      }
    end
  end
end
