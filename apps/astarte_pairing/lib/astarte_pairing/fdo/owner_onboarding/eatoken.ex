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
    with {:ok, eatoken_message} <- Sign1.verify_decode(eatoken_cbor, device_public_key),
         {:ok, payload} <- verify_payload(eatoken_message.payload, extra_payload_claims) do
      unprotected_headers =
        translate_unprotected_headers(eatoken_message.uhdr, extra_unprotected_header_claims)

      {:ok, %{eatoken_message | payload: payload, uhdr: unprotected_headers}}
    else
      _ -> :error
    end
  end

  defp translate_unprotected_headers(unprotected_headers, extra_claims) do
    known_claims = Map.merge(@known_unprotected_header_claims, extra_claims)
    translate_claims(unprotected_headers, known_claims)
  end

  defp verify_payload(payload, extra_claims) do
    known_claims = Map.merge(@known_payload_claims, extra_claims)

    case CBOR.decode(payload) do
      {:ok, raw_claims = %{}, _} -> {:ok, translate_claims(raw_claims, known_claims)}
      _ -> :error
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
