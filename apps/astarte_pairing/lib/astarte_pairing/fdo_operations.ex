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

defmodule Astarte.Pairing.FDOOperations do
  @moduledoc """
  Shared business logic for FDO operations, used by both the REST
  controllers and the GraphQL resolvers.
  """

  alias Astarte.FDO.OwnershipVoucher
  alias Astarte.FDO.OwnershipVoucher.LoadRequest
  alias Astarte.FDO.TO0

  require Logger

  @doc """
  Validates a voucher registration request, persists the voucher and claims
  ownership via TO0.
  """
  @spec register_ownership_voucher(map(), String.t()) ::
          {:ok, %{public_key: String.t(), guid: binary()}} | {:error, term()}
  def register_ownership_voucher(params, realm_name) do
    with {:ok, req} <-
           %LoadRequest{}
           |> LoadRequest.changeset(Map.put(params, "realm_name", realm_name))
           |> Ecto.Changeset.apply_action(:insert),
         :ok <- save_voucher(realm_name, req),
         :ok <- claim_ownership(realm_name, req) do
      {:ok, %{public_key: req.extracted_owner_key.public_pem, guid: req.device_guid}}
    end
  end

  defp save_voucher(realm_name, req) do
    OwnershipVoucher.save_voucher(realm_name, %{
      voucher_data: req.cbor_ownership_voucher,
      guid: req.device_guid,
      key_name: req.key_name,
      key_algorithm: req.key_algorithm,
      replacement_guid: req.replacement_guid,
      replacement_rendezvous_info: req.decoded_replacement_rendezvous_info,
      replacement_public_key: req.decoded_replacement_public_key
    })
  end

  defp claim_ownership(realm_name, req) do
    case TO0.claim_ownership_voucher(
           realm_name,
           req.decoded_ownership_voucher,
           req.extracted_owner_key
         ) do
      :ok ->
        :ok

      {:error, reason} ->
        Logger.error(
          "TO0 ownership claim failed after the voucher was already persisted: " <>
            "realm=#{inspect(realm_name)} guid=#{inspect(req.device_guid)} reason=#{inspect(reason)}. " <>
            "The voucher is registered but not claimed."
        )

        {:error, reason}
    end
  end
end
