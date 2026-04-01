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

defmodule Astarte.FDO.OwnershipVoucher.LoadRequest do
  @moduledoc """
  Changeset used to validate and parse an FDO Ownership Voucher load request.
  """

  use TypedEctoSchema

  alias Astarte.FDO.Core.OwnershipVoucher
  alias Astarte.FDO.Core.OwnershipVoucher.Core, as: OVCore
  alias Astarte.FDO.Core.PublicKey
  alias Astarte.FDO.OwnershipVoucher.LoadRequest
  alias Astarte.Secrets
  alias Astarte.Secrets.Key

  require Logger

  import Ecto.Changeset

  @allowed_key_algorithms ["ecdsa-p256", "ecdsa-p384", "rsa-2048", "rsa-3072"]

  typed_embedded_schema do
    field :ownership_voucher, :string
    field :realm_name, :string
    field :key_name, :string
    field :key_algorithm, :string
    field(:extracted_owner_key, :any, virtual: true) :: Key.t() | nil
    field :cbor_ownership_voucher, :binary

    field(:decoded_ownership_voucher, :any, virtual: true) ::
      OwnershipVoucher.decoded_voucher() | nil

    field(:voucher_struct, :any, virtual: true) :: struct() | nil
    field(:owner_key_algorithm, :any, virtual: true)
    field :device_guid, :binary
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%LoadRequest{} = request, params) do
    request
    |> cast(params, [:ownership_voucher, :realm_name, :key_name, :key_algorithm])
    |> validate_required([:ownership_voucher, :realm_name, :key_name, :key_algorithm])
    |> validate_inclusion(:key_algorithm, @allowed_key_algorithms)
    |> put_device_guid()
    |> fetch_owner_key()
    |> verify_owner_key_matches()
  end

  defp put_device_guid(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp put_device_guid(changeset) do
    ownership_voucher_pem = fetch_field!(changeset, :ownership_voucher)

    with {:ok, binary_voucher} <- OwnershipVoucher.binary_voucher(ownership_voucher_pem),
         {:ok, decoded_voucher, _rest} <- CBOR.decode(binary_voucher),
         {:ok, voucher_struct} <- OwnershipVoucher.decode(decoded_voucher) do
      changeset
      |> put_change(:cbor_ownership_voucher, binary_voucher)
      |> put_change(:decoded_ownership_voucher, decoded_voucher)
      |> put_change(:voucher_struct, voucher_struct)
      |> put_change(:device_guid, voucher_struct.header.guid)
    else
      err ->
        Logger.warning(
          "LoadRequest: failed to parse ownership voucher or extract key algorithm: #{inspect(err)}"
        )

        add_error(changeset, :ownership_voucher, "is not a valid ownership voucher")
    end
  end

  defp fetch_owner_key(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp fetch_owner_key(changeset) do
    realm_name = fetch_field!(changeset, :realm_name)
    key_name = fetch_field!(changeset, :key_name)
    key_algorithm = fetch_field!(changeset, :key_algorithm)

    with {:ok, namespace} <- Secrets.create_namespace(realm_name, key_algorithm),
         {:ok, key} <- Secrets.get_key(key_name, namespace: namespace) do
      put_change(changeset, :extracted_owner_key, key)
    else
      err ->
        Logger.warning(
          "LoadRequest: key_name \"#{key_name}\" not found in secrets store. " <>
            "The voucher's last entry requires a #{inspect(key_algorithm)} key, " <>
            "but no key with that name exists under that algorithm's namespace. " <>
            "Ensure the key is registered with the correct algorithm. " <>
            "Error: #{inspect(err)}"
        )

        add_error(changeset, :key_name, "does not exist in secrets store")
    end
  end

  defp verify_owner_key_matches(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp verify_owner_key_matches(changeset) do
    voucher_struct = fetch_field!(changeset, :voucher_struct)

    %Astarte.Secrets.Key{name: key_name, public_pem: pem} =
      fetch_field!(changeset, :extracted_owner_key)

    with {:ok, %PublicKey{encoding: voucher_key_encoding, body: voucher_key_body}} <-
           OVCore.entry_public_key(List.last(voucher_struct.entries)),
         true <- public_keys_match?(voucher_key_encoding, voucher_key_body, pem) do
      changeset
    else
      false ->
        Logger.warning(
          "LoadRequest: key_name \"#{key_name}\" was found in the secrets store " <>
            "but its public key DER bytes do not match " <>
            "the public key in the voucher's last entry. " <>
            "The voucher was not issued for this key."
        )

        add_error(
          changeset,
          :key_name,
          "does not match the public key in the ownership voucher's last entry"
        )

      err ->
        Logger.warning(
          "LoadRequest: failed to verify key \"#{key_name}\" against voucher entry: #{inspect(err)}"
        )

        add_error(
          changeset,
          :key_name,
          "does not match the public key in the ownership voucher's last entry"
        )
    end
  end

  # Extract the uncompressed EC point (<<4, x, y>>) from a SPKI PEM string.
  defp ec_point_from_pem(pem) do
    with [{_type, spki_der, :not_encrypted}] <- :public_key.pem_decode(pem),
         {:SubjectPublicKeyInfo, _alg, point} <-
           :public_key.der_decode(:SubjectPublicKeyInfo, spki_der) do
      {:ok, point}
    else
      _ -> :error
    end
  end

  # Extract the uncompressed EC point from the voucher entry body, depending on encoding.
  defp ec_point_from_voucher(:x509, spki_der) do
    case :public_key.der_decode(:SubjectPublicKeyInfo, spki_der) do
      {:SubjectPublicKeyInfo, _alg, point} -> {:ok, point}
      _ -> :error
    end
  end

  defp ec_point_from_voucher(:cosekey, cosekey_cbor) do
    with {:ok, cose_map, ""} <- CBOR.decode(cosekey_cbor),
         x when is_binary(x) <- Map.get(cose_map, -2),
         y when is_binary(y) <- Map.get(cose_map, -3) do
      {:ok, <<4, x::binary, y::binary>>}
    else
      _ -> :error
    end
  end

  defp ec_point_from_voucher(_encoding, _body), do: :error

  defp public_keys_match?(:x5chain, [first_cert_der | _], pem) do
    case ec_point_from_pem(pem) do
      {:ok, key_point} -> :binary.match(first_cert_der, key_point) != :nomatch
      _ -> false
    end
  end

  # TODO extend/correct this validation to work also for RSA keys
  defp public_keys_match?(voucher_key_encoding, voucher_key_body, pem) do
    with {:ok, voucher_point} <- ec_point_from_voucher(voucher_key_encoding, voucher_key_body),
         {:ok, key_point} <- ec_point_from_pem(pem) do
      voucher_point == key_point
    else
      _ -> false
    end
  end
end
