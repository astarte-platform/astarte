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
  alias COSE.Messages.Sign1

  @known_payload_claims %{
    10 => :nonce,
    256 => :ueid,
    -257 => :fdo
  }

  @known_unprotected_header_claims %{
    -258 => :maroeprefix,
    -259 => :euphnonce
  }

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
end
