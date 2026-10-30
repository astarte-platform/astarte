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

defmodule Astarte.Pairing.FDO.OwnershipVoucher do
  @moduledoc """
  Ownership voucher operations used by both the REST and the GraphQL API.
  """

  alias Astarte.FDO.OwnershipVoucher
  alias Astarte.FDO.OwnershipVoucher.LoadRequest
  alias Astarte.Pairing.Engine

  require Logger

  @doc """
  Validates a voucher registration request, claims ownership on the rendezvous
  server, persists the voucher and registers the device.
  """
  @spec register(map(), String.t()) ::
          {:ok, %{public_key: String.t(), guid: binary()}} | {:error, term()}
  def register(params, realm_name) do
    with {:ok, req} <- validate_request(params, realm_name),
         {:ok, expiry} <- claim_on_rendezvous(req),
         :ok <- store_voucher(realm_name, req, expiry),
         :ok <- register_device(realm_name, req) do
      {:ok, %{public_key: req.extracted_owner_key.public_pem, guid: req.device_guid}}
    end
  end

  defp validate_request(params, realm_name) do
    %LoadRequest{}
    |> LoadRequest.changeset(Map.put(params, "realm_name", realm_name))
    |> Ecto.Changeset.apply_action(:insert)
  end

  defp claim_on_rendezvous(req) do
    OwnershipVoucher.claim_on_rendezvous(
      req.device_guid,
      req.decoded_ownership_voucher,
      req.extracted_owner_key
    )
  end

  defp store_voucher(realm_name, req, expiry) do
    case LoadRequest.store_voucher(req, expiry) do
      :ok ->
        :ok

      {:error, reason} ->
        log_unfinished_registration(realm_name, req, "the voucher could not be persisted", reason)
        {:error, reason}
    end
  end

  defp register_device(realm_name, req) do
    opts = [
      initial_introspection: req.initial_introspection,
      with_credentials?: false,
      fdo_guid: req.device_guid
    ]

    case Engine.register_device(realm_name, req.hw_id, opts) do
      {:ok, nil} ->
        :ok

      {:error, reason} ->
        log_unfinished_registration(realm_name, req, "the device could not be registered", reason)
        {:error, reason}
    end
  end

  defp log_unfinished_registration(realm_name, req, what, reason) do
    Logger.error("Ownership was already claimed on the rendezvous server but #{what}!",
      realm: realm_name,
      fdo_guid: UUID.binary_to_string!(req.device_guid),
      reason: reason
    )
  end
end
