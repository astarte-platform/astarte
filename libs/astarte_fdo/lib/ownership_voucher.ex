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

defmodule Astarte.FDO.OwnershipVoucher do
  use TypedEctoSchema
  import Ecto.Changeset
  alias Astarte.FDO.OwnershipVoucher

  @primary_key false
  typed_schema "ownership_vouchers" do
    field :private_key, :binary
    field :voucher_data, :binary
    field :guid, Astarte.DataAccess.UUID, primary_key: true
  end

  @doc false
  def changeset(%OwnershipVoucher{} = ownership_voucher, attrs) do
    ownership_voucher
    |> cast(attrs, [:private_key, :voucher_data, :guid])
    |> validate_required([:private_key, :voucher_data, :guid])
  end
end
