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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.EAToken do
  @moduledoc """
  Functions for encoding and decoding Entity Attestation Tokens (EAT) used in FDO.

  EAT tokens are the COSE_Sign1 objects that contain attestation claims about a device.
  """
  alias COSE.Messages.Sign1

  # UEID prefix byte as per FDO specification
  @eat_random <<1>>

  # IANA & FDO EAT Claim mappings (Appendix E & Spec 3.3.6)
  @known_payload_claims %{
    # EAT-NONCE: Nonce claim for freshness
    10 => :nonce,
    # UEID: Universal Entity ID claim
    256 => :ueid,
    # EAT-FDO: FDO Claim wrapping the FDO payload
    -257 => :fdo
  }

  @known_unprotected_header_claims %{
    -258 => :maroeprefix
  }

  @doc """
  Builds a UEID (Universal Entity ID) by prepending the FDO-specified prefix byte
  to the given GUID.

  """
  def build_ueid(guid), do: @eat_random <> guid

  def parse_ueid(ueid) do
    case ueid do
      <<@eat_random, guid::binary-size(16)>> -> {:ok, guid}
      _ -> {:error, :invalid_ueid}
    end
  end

  @doc """
  Encodes and signs an EAToken with the given payload claims, unprotected header claims,
  and private key.

  """
  def encode_sign(
        payload_claims,
        uhdr_claims,
        priv_key,
        extra_payload_claims \\ %{},
        extra_unprotected_header_claims \\ %{}
      ) do
    eat_payload =
      translate_claims_encode(
        payload_claims,
        @known_payload_claims,
        extra_payload_claims
      )

    eat_uhdr =
      translate_claims_encode(
        uhdr_claims,
        @known_unprotected_header_claims,
        extra_unprotected_header_claims
      )

    eat_cbor_payload = CBOR.encode(eat_payload)
    phdr = %{alg: :es256}

    Sign1.build(eat_cbor_payload, phdr, eat_uhdr)
    |> Sign1.sign_encode_cbor(priv_key)
  end

  def verify_decode_cbor(
        eatoken_cbor,
        device_public_key,
        extra_payload_claims \\ %{},
        extra_unprotected_header_claims \\ %{}
      ) do
    with {:ok, decoded_eatoken} <- decode_eatoken(eatoken_cbor),
         {:ok, :verified} <- verify_signature(decoded_eatoken, device_public_key),
         {:ok, payload} <- verify_payload(decoded_eatoken.payload, extra_payload_claims) do
      unprotected_headers =
        translate_unprotected_headers(
          decoded_eatoken.uhdr,
          extra_unprotected_header_claims
        )

      {:ok, %{decoded_eatoken | payload: payload, uhdr: unprotected_headers}}
    end
  end

  defp decode_eatoken(eatoken_cbor) do
    case Sign1.decode_cbor(eatoken_cbor) do
      {:ok, decoded_eatoken} -> {:ok, decoded_eatoken}
      _ -> {:error, :message_body_error}
    end
  end

  defp translate_unprotected_headers(unprotected_headers, extra_claims) do
    known_claims = Map.merge(@known_unprotected_header_claims, extra_claims)
    translate_claims(unprotected_headers, known_claims)
  end

  defp verify_signature(decoded, device_public_key) do
    case Sign1.verify(decoded, device_public_key) do
      true -> {:ok, :verified}
      false -> {:error, :invalid_message}
    end
  end

  defp verify_payload(payload, extra_claims) do
    known_claims = Map.merge(@known_payload_claims, extra_claims)

    with %CBOR.Tag{tag: :bytes, value: cbor_payload} <- payload,
         {:ok, raw_claims = %{}, _} <- CBOR.decode(cbor_payload) do
      {:ok, translate_claims(raw_claims, known_claims)}
    else
      _ -> {:error, :message_body_error}
    end
  end

  defp translate_claims(claims, known_claims) do
    claims
    |> Map.new(fn {claim_id, value} ->
      claim = Map.get(known_claims, claim_id, claim_id)
      {claim, value}
    end)
  end

  defp translate_claims_encode(claims, known_claims, extra_claims) do
    all_claims = Map.merge(known_claims, extra_claims)
    atom_to_int = for {int, atom} <- all_claims, into: %{}, do: {atom, int}

    Map.new(claims, fn {key, value} ->
      int_key = Map.get(atom_to_int, key, key)
      {int_key, value}
    end)
  end
end
