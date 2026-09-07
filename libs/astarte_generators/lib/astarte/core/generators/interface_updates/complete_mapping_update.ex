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

defmodule Astarte.Core.Generators.InterfaceUpdates.CompleteMappingUpdate do
  @moduledoc """
  Generates complete Astarte interface updates.
  """

  import Astarte.Core.Generators.InterfaceUpdate, only: [valid_mapping_update_for: 3]

  alias Astarte.Core.Interface

  @doc """
  Generates an object update containing every interface mapping.
  """
  @spec valid_complete_mapping_update_for(
          Interface.t(),
          Astarte.Core.Generators.InterfaceUpdate.representation_t()
        ) :: StreamData.t(Astarte.Core.Generators.InterfaceUpdate.t())
  @spec valid_complete_mapping_update_for(
          Interface.t(),
          Astarte.Core.Generators.InterfaceUpdate.representation_t(),
          keyword()
        ) :: StreamData.t(Astarte.Core.Generators.InterfaceUpdate.t())
  def valid_complete_mapping_update_for(interface, representation, params \\ []),
    do:
      valid_mapping_update_for(
        interface,
        representation,
        Keyword.put(params, :selection, :complete)
      )
end
