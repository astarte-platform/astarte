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

defmodule Astarte.RealmManagement.Interfaces.InterfacesListOptions do
  @moduledoc """
  Options for retrieving lists of interfaces
  """

  use TypedEctoSchema
  import Ecto.Changeset
  alias Astarte.RealmManagement.Interfaces.InterfacesListOptions

  typed_embedded_schema do
    field :detailed, :boolean, default: false
  end

  def changeset(options, params) do
    options
    |> cast(params, [:detailed])
  end

  def from_params(params) do
    %InterfacesListOptions{}
    |> changeset(params)
    |> apply_action(:insert)
  end
end
