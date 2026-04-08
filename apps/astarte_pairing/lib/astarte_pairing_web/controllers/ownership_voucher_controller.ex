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

  alias Astarte.FDO.OwnershipVoucher
  alias Astarte.FDO.OwnershipVoucher.LoadRequest
  alias Astarte.FDO.TO0
  alias Astarte.PairingWeb.OwnershipVoucherView
  alias Astarte.Secrets.Core, as: SecretsCore

  action_fallback Astarte.PairingWeb.FallbackController

  @doc """
  Validates an FDO Ownership Voucher load request and register the OV in the database.

  Returns `200 OK` with the owner public key PEM on success.
  """
  def register(conn, %{"data" => data, "realm_name" => realm_name}) do
    with {:ok, req} <-
           LoadRequest.changeset(%LoadRequest{}, Map.put(data, "realm_name", realm_name))
           |> Ecto.Changeset.apply_action(:insert),
         :ok <-
           OwnershipVoucher.save_voucher(realm_name, %{
             voucher_data: req.cbor_ownership_voucher,
             guid: req.device_guid,
             key_name: req.key_name,
             key_algorithm: req.key_algorithm,
             replacement_guid: req.replacement_guid,
             replacement_rendezvous_info: req.decoded_replacement_rendezvous_info,
             replacement_public_key: req.decoded_replacement_public_key
           }),
         :ok <-
           TO0.claim_ownership_voucher(
             realm_name,
             req.decoded_ownership_voucher,
             req.extracted_owner_key
           ) do
      json(conn, %{
        data: %{
          public_key: req.extracted_owner_key.public_pem,
          guid: UUID.binary_to_string!(req.device_guid)
        }
      })
    end
  end

  @doc """
  List ownership vouchers.
  """
  def list_ownership_vouchers(conn, %{"realm_name" => realm_name}) do
    with {:ok, vouchers} <- OwnershipVoucher.list(realm_name) do
      conn
      |> put_view(OwnershipVoucherView)
      |> render("list_vouchers.json", ownership_vouchers: vouchers)
    end
  end

  @doc """
  Returns the list of registered owner keys that are compatible with the
  given ownership voucher.

  Returns `200 OK` with `{"data": {"<algorithm>": ["key_name", ...]}}` on success.
  """
  def owner_keys_for_voucher(conn, %{"data" => data, "realm_name" => realm_name}) do
    with {:ok, pem} <- ensure_ownership_voucher_parameter(data),
         {:ok, voucher} <- OwnershipVoucher.decode_binary_voucher(pem),
         key_algorithm = OwnershipVoucher.key_algorithm(voucher),
         {:ok, keys_map} <- SecretsCore.get_keys(realm_name, key_algorithm) do
      json(conn, %{data: keys_map})
    end
  end

  defp ensure_ownership_voucher_parameter(%{"ownership_voucher" => pem})
       when is_binary(pem) and pem != "",
       do: {:ok, pem}

  defp ensure_ownership_voucher_parameter(_params),
    do: {:error, :missing_ownership_voucher}
end
