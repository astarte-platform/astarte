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

defmodule Astarte.RealmManagement.Generators.Name do
  @moduledoc """
  Generator for `Astarte.DataAccess.Realms.Name` structures
  """
  alias Astarte.Core.Generators.Device
  alias Astarte.DataAccess.Realms.Name
  alias Astarte.Generators.Utilities.ParamsGen

  use ExUnitProperties

  import ParamsGen

  def name(params) do
    params gen(
             all(
               device_id <- Device.id(),
               alias <- string(:utf8, length: 1..100),
               object_type <- integer(0..256),
               params: params
             )
           ) do
      %Name{
        object_uuid: device_id,
        object_name: alias,
        object_type: object_type
      }
    end
  end
end
