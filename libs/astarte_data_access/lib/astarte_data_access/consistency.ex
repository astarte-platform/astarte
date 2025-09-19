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

defmodule Astarte.DataAccess.Consistency do
  alias Astarte.Core.Mapping
  alias Astarte.DataAccess.Config

  def domain_model(:read), do: Config.domain_model_read_consistency!()
  def domain_model(:write), do: Config.domain_model_write_consistency!()

  def device_info(:read), do: Config.device_info_read_consistency!()
  def device_info(:write), do: Config.device_info_write_consistency!()

  # TODO Xandra does not support :any consistency. Use the standard approach
  # when https://github.com/whatyouhide/xandra/issues/380 is closed.
  def time_series(:write, %Mapping{reliability: :unreliable}) do
    :one
  end

  def time_series(operation, mapping) do
    Config.time_series_consistency(operation, mapping)
  end
end
