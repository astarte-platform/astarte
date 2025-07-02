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

defmodule Astarte.RealmManagement.Generators.IndividualProperty do
  @moduledoc """
  Generators of `IndividualProperty`es
  """
  alias Astarte.Generators.Utilities.ParamsGen
  alias Astarte.DataAccess.Realms.IndividualProperty
  alias Ecto.UUID

  use ExUnitProperties

  import ParamsGen

  def individual_property(params \\ []) do
    params gen(
             all(
               interface_id <- repeatedly(&UUID.bingenerate/0),
               device_id <- repeatedly(&UUID.bingenerate/0),
               endpoint_id <- repeatedly(&UUID.bingenerate/0),
               path <-
                 :ascii
                 |> string(length: 1..10)
                 |> list_of(length: 1..5)
                 |> map(fn paths -> "/" <> Enum.join(paths, "/") end),
               params: params
             )
           ) do
      %IndividualProperty{
        device_id: device_id,
        interface_id: interface_id,
        endpoint_id: endpoint_id,
        path: path
      }
    end
  end
end
