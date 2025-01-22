#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule Astarte.Test.Generators.Group do
  use ExUnitProperties

  @max_subpath_count 10
  @max_subpath_length 20

  def name() do
    string(:ascii, min_length: 1, max_length: @max_subpath_length)
    |> uniq_list_of(
      min_length: 1,
      max_length: @max_subpath_count
    )
    |> map(&Enum.join(&1, "/"))
    |> filter(fn name ->
      String.first(name) not in ["@", "~", "\s"]
    end)
  end

  def group(devices: devices) do
    gen all name <- name(),
            device_ids <-
              devices
              |> Enum.map(fn i -> i.device_id end)
              |> constant() do
      %{
        name: name,
        device_ids: device_ids
      }
    end
  end
end
