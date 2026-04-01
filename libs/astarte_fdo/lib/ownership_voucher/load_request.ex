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
  alias Astarte.FDO.Core.OwnershipVoucher.RendezvousInfo
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
    field(:owner_voucher_public_key, :any, virtual: true) :: PublicKey.t() | nil
    field :replacement_rendezvous_info, :binary
    field :replacement_public_key, :string
    field :replacement_guid, :binary
    field(:decoded_replacement_rendezvous_info, :any, virtual: true) :: RendezvousInfo.t() | nil
    field(:decoded_replacement_public_key, :any, virtual: true) :: PublicKey.t() | nil
  end

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(%LoadRequest{} = request, params) do
    request
    |> cast(params, [
      :ownership_voucher,
      :realm_name,
      :key_name,
      :key_algorithm,
      :replacement_rendezvous_info,
      :replacement_public_key,
      :replacement_guid
    ])
    |> validate_required([:ownership_voucher, :realm_name, :key_name, :key_algorithm])
    |> validate_inclusion(:key_algorithm, @allowed_key_algorithms)
    |> put_device_guid()
    |> fetch_owner_key()
    |> verify_owner_key_matches()
    |> validate_replacement_rendezvous_info()
    |> validate_replacement_public_key()
    |> validate_replacement_guid()
  end

  defp put_device_guid(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp put_device_guid(changeset) do
    ownership_voucher_pem = fetch_field!(changeset, :ownership_voucher)

    with {:ok, binary_voucher} <- OwnershipVoucher.binary_voucher(ownership_voucher_pem),
         {:ok, decoded_voucher, _rest} <- CBOR.decode(binary_voucher),
         {:ok, voucher_struct} <- OwnershipVoucher.decode(decoded_voucher),
         {:ok, owner_public_key} <-
           OVCore.entry_public_key(List.last(voucher_struct.entries)) do
      changeset
      |> put_change(:cbor_ownership_voucher, binary_voucher)
      |> put_change(:decoded_ownership_voucher, decoded_voucher)
      |> put_change(:voucher_struct, voucher_struct)
      |> put_change(:owner_voucher_public_key, owner_public_key)
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
      _err ->
        add_error(changeset, :key_name, "does not exist in secrets store")
    end
  end

  defp verify_owner_key_matches(%Ecto.Changeset{valid?: false} = changeset), do: changeset

  defp verify_owner_key_matches(changeset) do
    %Astarte.Secrets.Key{name: key_name, public_pem: pem} =
      fetch_field!(changeset, :extracted_owner_key)

    %PublicKey{encoding: encoding, body: voucher_body} =
      fetch_field!(changeset, :owner_voucher_public_key)

    if public_keys_match?(encoding, voucher_body, pem) do
      changeset
    else
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
    end
  end

  # :x509 — voucher body is SPKI DER; PEM decodes to SPKI DER. Direct byte comparison.
  defp public_keys_match?(:x509, voucher_spki_der, pem) do
    case :public_key.pem_decode(pem) do
      [{_, pem_spki_der, :not_encrypted}] -> pem_spki_der == voucher_spki_der
      _ -> false
    end
  end

  # :x5chain — extract SPKI DER from the first cert, compare with PEM SPKI DER.
  defp public_keys_match?(:x5chain, [first_cert_der | _], pem) do
    with {:ok, cert_spki_der} <- spki_der_from_cert(first_cert_der),
         [{_, pem_spki_der, :not_encrypted}] <- :public_key.pem_decode(pem) do
      cert_spki_der == pem_spki_der
    else
      _ -> false
    end
  end

  # :cosekey — decode CBOR map, decode PEM via OTP, compare key material.
  defp public_keys_match?(:cosekey, cosekey_cbor, pem) do
    with {:ok, cose_map, ""} <- CBOR.decode(cosekey_cbor),
         [{_, _, :not_encrypted} = entry] <- :public_key.pem_decode(pem),
         key_record <- :public_key.pem_entry_decode(entry) do
      cose_record_equal?(cose_map, key_record)
    else
      _ -> false
    end
  end

  defp public_keys_match?(_, _, _), do: false

  # Extract the SubjectPublicKeyInfo DER bytes embedded in an X.509 certificate.
  defp spki_der_from_cert(cert_der) do
    try do
      {:Certificate, {:TBSCertificate, _, _, _, _, _, _, spki, _, _, _}, _, _} =
        :public_key.pkix_decode_cert(cert_der, :plain)

      {:ok, :public_key.der_encode(:SubjectPublicKeyInfo, spki)}
    rescue
      _ -> :error
    end
  end

  # EC public key: pem_entry_decode yields {{:ECPoint, <<4,x,y>>}, {:namedCurve, oid}}
  # COSE map: -2 => x bytes, -3 => y bytes
  defp cose_record_equal?(
         cose_map,
         {{:ECPoint, <<4, x::binary-size(32), y::binary-size(32)>>}, _}
       ) do
    Map.get(cose_map, -2) == x and Map.get(cose_map, -3) == y
  end

  defp cose_record_equal?(
         cose_map,
         {{:ECPoint, <<4, x::binary-size(48), y::binary-size(48)>>}, _}
       ) do
    Map.get(cose_map, -2) == x and Map.get(cose_map, -3) == y
  end

  # RSA public key: pem_entry_decode yields {:RSAPublicKey, n_int, e_int}
  # COSE map: -1 => n bytes, -2 => e bytes
  defp cose_record_equal?(cose_map, {:RSAPublicKey, n, e}) do
    Map.get(cose_map, -1) == :binary.encode_unsigned(n) and
      Map.get(cose_map, -2) == :binary.encode_unsigned(e)
  end

  defp cose_record_equal?(_, _), do: false

  defp validate_replacement_rendezvous_info(changeset) do
    validate_change(changeset, :replacement_rendezvous_info, fn :replacement_rendezvous_info,
                                                                b64_string ->
      with {:ok, cbor_binary} <- Base.decode64(b64_string),
           {:ok, _} <- RendezvousInfo.decode_cbor(cbor_binary) do
        []
      else
        _ -> [replacement_rendezvous_info: "is not valid base64-encoded CBOR rendezvous info"]
      end
    end)
  end

  defp validate_replacement_public_key(changeset) do
    validate_change(changeset, :replacement_public_key, fn :replacement_public_key, pem_string ->
      case public_key_from_pem(pem_string) do
        {:ok, _} -> []
        :error -> [replacement_public_key: "is not a valid PEM public key"]
      end
    end)
  end

  defp validate_replacement_guid(changeset) do
    validate_change(changeset, :replacement_guid, fn :replacement_guid, b64_string ->
      case Base.decode64(b64_string) do
        {:ok, _} -> []
        :error -> [replacement_guid: "is not valid base64"]
      end
    end)
  end

  defp public_key_from_pem(pem_string) do
    with [{:SubjectPublicKeyInfo, spki_der, :not_encrypted} = entry] <-
           :public_key.pem_decode(pem_string),
         {:ok, key_type} <- key_type_from_spki(spki_der, entry) do
      {:ok, %PublicKey{type: key_type, encoding: :x509, body: spki_der}}
    else
      _ -> :error
    end
  end

  # For EC: pem_entry_decode resolves the curve OID to a named tuple directly.
  # For RSA: der_decode the SPKI to read the algorithm OID (PKCS#1 vs PSS),
  #          since pem_entry_decode strips it, returning identical {:RSAPublicKey, n, e} for both.
  defp key_type_from_spki(spki_der, entry) do
    case :public_key.pem_entry_decode(entry) do
      {{:ECPoint, _}, {:namedCurve, {1, 2, 840, 10_045, 3, 1, 7}}} ->
        {:ok, :secp256r1}

      {{:ECPoint, _}, {:namedCurve, {1, 3, 132, 0, 34}}} ->
        {:ok, :secp384r1}

      {:RSAPublicKey, _, _} ->
        case :public_key.der_decode(:SubjectPublicKeyInfo, spki_der) do
          {:SubjectPublicKeyInfo, {:AlgorithmIdentifier, {1, 2, 840, 113_549, 1, 1, 10}, _}, _} ->
            {:ok, :rsapss}

          {:SubjectPublicKeyInfo, {:AlgorithmIdentifier, _, _}, _} ->
            {:ok, :rsapkcs}

          _ ->
            :error
        end

      _ ->
        :error
    end
  end
end
