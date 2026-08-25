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

defmodule Astarte.PairingWeb.GraphQL.Types.FdoTypes do
  use Absinthe.Schema.Notation

  alias Astarte.DataAccess.FDO.OwnershipVoucher

  enum :key_algorithm do
    value :es256, as: "ecdsa-p256"
    value :es384, as: "ecdsa-p384"
    value :rs256, as: "rsa-2048"
    value :rs384, as: "rsa-3072"
  end

  # Reuses the status values already defined on the Ecto schema.
  enum :ownership_voucher_status, values: Ecto.Enum.values(OwnershipVoucher, :status)

  object :owner_keys_map do
    field :es256, list_of(:string)
    field :es384, list_of(:string)
    field :rs256, list_of(:string)
    field :rs384, list_of(:string)
  end

  object :owner_key do
    field :key_name, non_null(:string)
    field :public_key, non_null(:string)
  end

  object :ownership_voucher do
    field :guid, non_null(:string)
    field :status, non_null(:ownership_voucher_status)
    field :output_guid, :string
    field :input_voucher, non_null(:string)
    field :output_voucher, :string
  end

  object :register_ownership_voucher_response do
    field :public_key, non_null(:string)
    field :guid, non_null(:string)
  end
end
