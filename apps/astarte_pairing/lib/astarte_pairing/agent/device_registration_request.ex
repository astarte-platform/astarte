#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.Agent.DeviceRegistrationRequest do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias Astarte.FDO.OwnershipVoucher.LoadRequest
  alias Astarte.Pairing.Agent.DeviceRegistrationRequest

  @primary_key false
  embedded_schema do
    field :hw_id, :string
    field :initial_introspection, :map, default: %{}
  end

  @doc false
  def changeset(%DeviceRegistrationRequest{} = request, attrs) do
    request
    |> cast(attrs, [:hw_id, :initial_introspection])
    |> validate_required([:hw_id])
    |> LoadRequest.validate_hw_id(:hw_id)
    |> validate_change(:initial_introspection, &LoadRequest.validate_introspection/2)
  end
end
