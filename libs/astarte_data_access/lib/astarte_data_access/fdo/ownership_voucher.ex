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

defmodule Astarte.DataAccess.FDO.OwnershipVoucher do
  @moduledoc """
  Ecto schema for persisting ownership voucher binary data to the database.
  """
  use TypedEctoSchema

  import Ecto.Changeset

  alias Astarte.DataAccess.FDO.CBOR.Encoded, as: CBOREncoded
  alias Astarte.DataAccess.FDO.OwnershipVoucher
  alias Astarte.FDO.Core.OwnershipVoucher.RendezvousInfo
  alias Astarte.FDO.Core.PublicKey

  @primary_key false
  typed_schema "ownership_vouchers" do
    field :guid, Astarte.DataAccess.UUID, primary_key: true
    field :voucher_data, :binary
    field :output_voucher, :binary
    field :user_id, :binary
    field :key_name, :string
    field :key_algorithm, Ecto.Enum, values: [es256: 0, es384: 1, rs256: 10, rs384: 11]
    field :replacement_guid, :binary
    field :replacement_rv_info, CBOREncoded, using: RendezvousInfo
    field :replacement_pub_key, CBOREncoded, using: PublicKey
  end

  @doc false
  def changeset(%OwnershipVoucher{} = record, attrs) do
    record
    |> cast(attrs, [
      :key_name,
      :voucher_data,
      :guid,
      :key_algorithm,
      :replacement_guid,
      :replacement_rv_info,
      :replacement_pub_key
    ])
    |> validate_required([:key_name, :key_algorithm, :voucher_data, :guid])
  end
end
