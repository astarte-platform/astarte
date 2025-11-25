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

defmodule Astarte.Pairing.FDO.OwnershipVoucher.CreateRequest do
  use TypedEctoSchema

  alias Astarte.Pairing.FDO.OwnershipVoucher.CreateRequest
  alias Astarte.Pairing.FDO.OwnershipVoucher.Core

  require Logger

  import Ecto.Changeset

  typed_embedded_schema do
    field :ownership_voucher, :string
    field :private_key, :string
    field(:extracted_private_key, :any, virtual: true) :: :public_key.private_key()
    field :cbor_ownership_voucher, :binary
    field(:decoded_ownership_voucher, :any, virtual: true) :: Core.decoded_voucher()
    field :device_guid, :binary
  end

  def changeset(request = %CreateRequest{}, params) do
    request
    |> cast(params, [:ownership_voucher, :private_key])
    |> validate_required([:ownership_voucher, :private_key])
    |> put_device_guid()
    |> extract_private_key()
  end

  defp put_device_guid(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp put_device_guid(changeset) do
    # SAFETY: we've validated the field is required and we only accept valid changesets
    ownership_voucher = fetch_field!(changeset, :ownership_voucher)

    with {:ok, binary_voucher} <- Core.binary_voucher(ownership_voucher),
         {:ok, decoded_voucher, _rest} <- CBOR.decode(binary_voucher),
         {:ok, device_guid} <- Core.device_guid(decoded_voucher) do
      changeset
      |> put_change(:cbor_ownership_voucher, binary_voucher)
      |> put_change(:decoded_ownership_voucher, decoded_voucher)
      |> put_change(:device_guid, device_guid)
    else
      _err ->
        add_error(changeset, :ownership_voucher, "is not a valid ownership voucher")
    end
  end

  defp extract_private_key(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp extract_private_key(changeset) do
    # SAFETY: we've validated the field is required and we only accept valid changesets
    private_key = fetch_field!(changeset, :private_key)

    case COSE.Keys.from_pem(private_key) do
      {:ok, key} -> put_change(changeset, :extracted_private_key, key)
      :error -> add_error(changeset, :private_key, "must be a valid EC or RSA private key")
    end
  end
end
