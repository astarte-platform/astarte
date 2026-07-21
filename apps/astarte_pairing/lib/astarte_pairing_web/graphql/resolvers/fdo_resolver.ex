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
  alias Astarte.Secrets
  alias Astarte.Secrets.OwnerKeyInitialization
  alias Astarte.Secrets.OwnerKeyInitializationOptions
  alias Astarte.FDO.OwnershipVoucher
  alias Astarte.FDO.OwnershipVoucher.LoadRequest
  alias Astarte.FDO.TO0

  def list_owner_keys(_parent, %{key_algorithm: alg}, %{context: %{realm_name: realm}}) do
    with {:ok, algorithm_atom} <- Secrets.Core.string_to_key_type(alg),
         {:ok, keys} <- Secrets.Core.get_keys(realm, [algorithm_atom]) do
      {:ok, keys}
    end
  end

  def list_owner_keys(_parent, _args, %{context: %{realm_name: realm}}) do
    supported_key_algorithms = [:es256, :es384, :rs256, :rs384]
    with {:ok, keys} <- Secrets.Core.get_keys(realm, supported_key_algorithms) do
      {:ok, keys}
    end
  end

  def get_owner_key(_parent, %{key_algorithm: alg, key_name: key_name}, %{context: %{realm_name: realm}}) do
    with {:ok, algorithm_atom} <- Secrets.Core.string_to_key_type(alg),
         {:ok, key} <- Secrets.Core.find_key(realm, key_name, algorithm_atom) do
      {:ok, %{key_name: key.name, public_key: key.public_pem}}
    else
      :error -> {:error, "Invalid key algorithm"}
      :not_found -> {:error, "Key not found"}
    end
  end

  def create_or_upload_owner_key(_parent, args, %{context: %{realm_name: realm}}) do
    # Map atom keys to string keys for changeset casting
    params = for {k, v} <- args, into: %{}, do: {Atom.to_string(k), v}
    changeset = OwnerKeyInitializationOptions.changeset(%OwnerKeyInitializationOptions{}, params)

    with {:ok, validated_options} <- Ecto.Changeset.apply_action(changeset, :insert),
         {:ok, resp} <- OwnerKeyInitialization.create_or_upload(validated_options, realm) do
      {:ok, resp}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, "Validation failed: #{inspect(changeset.errors)}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  def owner_keys_for_voucher(_parent, %{ownership_voucher: pem}, %{context: %{realm_name: realm}}) do
    with {:ok, voucher} <- OwnershipVoucher.decode_binary_voucher(pem),
         key_algorithm = OwnershipVoucher.key_algorithm(voucher),
         {:ok, keys_map} <- Secrets.Core.get_keys(realm, key_algorithm) do
      {:ok, keys_map}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def list_ownership_vouchers(_parent, _args, %{context: %{realm_name: realm}}) do
    with {:ok, vouchers} <- OwnershipVoucher.list(realm) do
      formatted_vouchers = Enum.map(vouchers, fn v ->
        %{
          guid: UUID.binary_to_string!(v.guid),
          status: v.status,
          output_guid: if(v.replacement_guid, do: UUID.binary_to_string!(v.replacement_guid)),
          input_voucher: format_binary_voucher(v.voucher_data),
          output_voucher: if(v.output_voucher, do: format_binary_voucher(v.output_voucher))
        }
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
      "replacement_rendezvous_info" => Map.get(args, :replacement_rendezvous_info),
      "realm_name" => realm
    }

    with {:ok, req} <- LoadRequest.changeset(%LoadRequest{}, params) |> Ecto.Changeset.apply_action(:insert),
         :ok <- OwnershipVoucher.save_voucher(realm, %{
           voucher_data: req.cbor_ownership_voucher,
           guid: req.device_guid,
           key_name: req.key_name,
           key_algorithm: req.key_algorithm,
           replacement_guid: req.replacement_guid,
           replacement_rendezvous_info: req.decoded_replacement_rendezvous_info,
           replacement_public_key: req.decoded_replacement_public_key
         }),
         :ok <- TO0.claim_ownership_voucher(realm, req.decoded_ownership_voucher, req.extracted_owner_key) do
      {:ok, %{
        public_key: req.extracted_owner_key.public_pem,
        guid: UUID.binary_to_string!(req.device_guid)
      }}
    else
      {:error, %Ecto.Changeset{} = changeset} ->
        {:error, "Validation failed: #{inspect(changeset.errors)}"}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp format_binary_voucher(binary_voucher) do
    encoded =
      Base.encode64(binary_voucher)
      |> String.to_charlist()
      |> Enum.chunk_every(64)
      |> Enum.intersperse("\n")
      |> List.flatten()

    """
    -----BEGIN OWNERSHIP VOUCHER-----
    #{encoded}
    -----END OWNERSHIP VOUCHER-----
    """
  end
end
