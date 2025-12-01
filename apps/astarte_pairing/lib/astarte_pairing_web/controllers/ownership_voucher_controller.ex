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

defmodule Astarte.PairingWeb.OwnershipVoucherController do
  use Astarte.PairingWeb, :controller

  alias Astarte.Pairing.FDO
  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias Astarte.Pairing.FDO.OwnershipVoucher.CreateRequest

  action_fallback Astarte.PairingWeb.FallbackController

  def create(conn, %{
        "data" => data,
        "realm_name" => realm_name
      }) do
    create = CreateRequest.changeset(%CreateRequest{}, data)

    with {:ok, create} <- Ecto.Changeset.apply_action(create, :insert),
         %CreateRequest{
           decoded_ownership_voucher: decoded_ownership_voucher,
           cbor_ownership_voucher: cbor_ownership_voucher,
           private_key: private_key,
           extracted_private_key: extracted_private_key,
           device_guid: device_guid
         } = create,
         :ok <-
           OwnershipVoucher.save_voucher(
             realm_name,
             cbor_ownership_voucher,
             device_guid,
             private_key
           ),
         :ok <-
           FDO.claim_ownership_voucher(
             realm_name,
             decoded_ownership_voucher,
             extracted_private_key
           ) do
      send_resp(conn, 200, "")
    end
  end
end
