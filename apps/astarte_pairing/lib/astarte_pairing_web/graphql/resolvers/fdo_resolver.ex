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

defmodule Astarte.PairingWeb.GraphQL.Resolvers.FdoResolver do
  @moduledoc """
  Absinthe resolvers for FDO-related GraphQL fields: owner key management
  and ownership voucher operations.
  """

  alias Astarte.FDO.OwnershipVoucher
  alias Astarte.Pairing.FDOOperations
  alias Astarte.PairingWeb.ChangesetView
  alias Astarte.PairingWeb.OwnershipVoucherView
  alias Astarte.Secrets
  alias Astarte.Secrets.OwnerKeyInitialization
  alias Astarte.Secrets.OwnerKeyInitializationOptions

  def list_owner_keys(_parent, %{key_algorithm: alg}, %{context: %{realm_name: realm}}) do
    with {:ok, algorithm_atom} <- Secrets.Core.string_to_key_type(alg) do
      Secrets.Core.get_keys(realm, [algorithm_atom])
    end
  end

  def list_owner_keys(_parent, _args, %{context: %{realm_name: realm}}) do
    supported_key_algorithms = [:es256, :es384, :rs256, :rs384]

    Secrets.Core.get_keys(realm, supported_key_algorithms)
  end

  def get_owner_key(_parent, %{key_algorithm: alg, key_name: key_name}, %{
        context: %{realm_name: realm}
      }) do
    with {:ok, algorithm_atom} <- Secrets.Core.string_to_key_type(alg),
         {:ok, key} <- Secrets.Core.find_key(realm, key_name, algorithm_atom) do
      {:ok, %{key_name: key.name, public_key: key.public_pem}}
    else
      :error -> {:error, "Invalid key algorithm"}
      :not_found -> {:error, "Key not found"}
    end
  end

  def create_or_upload_owner_key(_parent, args, %{context: %{realm_name: realm}}) do
    changeset = OwnerKeyInitializationOptions.changeset(%OwnerKeyInitializationOptions{}, args)

    with {:ok, validated_options} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, resp} <- OwnerKeyInitialization.create_or_upload(validated_options, realm) do
      {:ok, resp}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, "Validation failed: #{format_changeset_errors(changeset)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def owner_keys_for_voucher(_parent, %{ownership_voucher: pem}, %{context: %{realm_name: realm}}) do
    with {:ok, voucher} <- OwnershipVoucher.decode_binary_voucher(pem) do
      key_algorithm = OwnershipVoucher.key_algorithm(voucher)
      Secrets.Core.get_keys(realm, key_algorithm)
    end
  end

  def list_ownership_vouchers(_parent, _args, %{context: %{realm_name: realm}}) do
    with {:ok, vouchers} <- OwnershipVoucher.list(realm) do
      formatted_vouchers =
        Enum.map(vouchers, fn voucher ->
          OwnershipVoucherView.render("ownership_voucher.json", %{ownership_voucher: voucher})
        end)

      {:ok, formatted_vouchers}
    end
  end

  def register_ownership_voucher(_parent, args, %{context: %{realm_name: realm}}) do
    params = %{
      "ownership_voucher" => args.ownership_voucher,
      "key_name" => args.key_name,
      "key_algorithm" => args.key_algorithm,
      "replacement_public_key" => Map.get(args, :replacement_public_key),
      "replacement_guid" => Map.get(args, :replacement_guid),
      "replacement_rendezvous_info" => Map.get(args, :replacement_rendezvous_info)
    }

    case FDOOperations.register_ownership_voucher(params, realm) do
      {:ok, resp} ->
        {:ok,
         %{
           public_key: resp.public_key,
           guid: UUID.binary_to_string!(resp.guid)
         }}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, "Validation failed: #{format_changeset_errors(changeset)}"}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_changeset_errors(changeset) do
    changeset
    |> ChangesetView.translate_errors()
    |> Jason.encode!()
  end
end
