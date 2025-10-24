#
# This file is part of Astarte.
#
# Copyright 2017-2025 SECO Mind Srl
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

defmodule Astarte.Pairing.TO0Util do
  require Logger

  # According to FDO spec 5.3.2: TO0.HelloAck = [NonceTO0Sign]
  def getNonceFromHelloAck(body) do
    case CBOR.decode(body) do
      {:ok, decoded, _rest} when is_list(decoded) and length(decoded) == 1 ->
        [nonce_to_sign] = decoded
        {:ok, nonce_to_sign}
      {:error, reason} ->
        Logger.warning("Failed to decode TO0.HelloAck CBOR", reason: reason)
        {:error, {:cbor_decode_error, reason}}
    end
  end

  def decode_ownership_voucher() do
    path = Path.join([:code.priv_dir(:astarte_pairing), "ownership-voucher.pem"])

    with {:ok, content} <- File.read(path),
         ov_data <-
           content
           |> String.replace("-----BEGIN OWNERSHIP VOUCHER-----", "")
           |> String.replace("-----END OWNERSHIP VOUCHER-----", "")
           |> String.replace(~r/\s/, ""),
         {:ok, cbor_data} <- Base.decode64(ov_data),
         {:ok, result, _rest} <- CBOR.decode(cbor_data) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
      :error -> {:error, "Invalid base64 in PEM"}
      other -> {:error, "PEM parsing failed: #{inspect(other)}"}
    end
  end

  def getOwnerPrivateKey() do
    path = Path.join([:code.priv_dir(:astarte_pairing), "owner-key.pem"])

    case File.read(path) do
      {:ok, content} ->
        {:ok, content}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def sign_with_owner_key(data) do
    with {:ok, pem_data} <- getOwnerPrivateKey(),
         [{:ECPrivateKey, der_data, :not_encrypted}] <- :public_key.pem_decode(pem_data),
         {:ok, ec_private_key} <- safe_der_decode(der_data),
         {:ok, raw_priv} <- extract_raw_private_key(ec_private_key),
         {:ok, signature} <- safe_sign(data, raw_priv) do
      {:ok, signature}
    else
      error ->
        Logger.error("Signing failed", error: inspect(error))
        {:error, error}
    end
  end

  defp safe_der_decode(der_data) do
    try do
      {:ok, :public_key.der_decode(:ECPrivateKey, der_data)}
    rescue
      e -> {:error, {:der_decode_failed, e}}
    end
  end

  defp extract_raw_private_key({:ECPrivateKey, _version, bin, _params, _pub, _extra}) do
    case byte_size(bin) do
      32 -> {:ok, bin}
      n when n < 32 -> {:ok, :binary.copy(<<0>>, 32 - n) <> bin}
      n -> {:error, {:key_too_long, n}}
    end
  end

  defp safe_sign(data, priv_key) do
    try do
      {:ok, :crypto.sign(:ecdsa, :sha256, data, [priv_key, :secp256r1])}
    rescue
      e -> {:error, {:signing_failed, e}}
    end
  end

  defp build_rvto2addr_entry(ip, dns, port, protocol) do

    rv_entry = [
      ip,
      dns,
      port,
      protocol
    ]
    with encoded_entry <- CBOR.encode([rv_entry]) do
      {:ok, encoded_entry}
    end
  end

  defp buildto1dRV(entries) do
    with to1dRV <- CBOR.encode([entries]) do
      {:ok, to1dRV}
    end
  end

  defp build_to0d(ov, wait_seconds, nonce) do
    with to0d <- CBOR.encode([ov, wait_seconds, nonce]) do
      {:ok, to0d}
    end
  end

  defp buildto1dTo0dHash(to0d) do
    with to1d_to0d_hash_value <- :crypto.hash(:sha256, to0d),
         # 47 is the key for SHA-256
         to1dTo0dHash <- CBOR.encode([47, to1d_to0d_hash_value]) do
      {:ok, to1dTo0dHash}
    end
  end

  defp buildto1dBlobPayload(to1dRV, to1dTo0dHash) do
    with blob_payload <- CBOR.encode([to1dRV, to1dTo0dHash]) do
      {:ok, blob_payload}
    end
  end

  def build_cose_sign1(payload) do
    try do
      # Protected header: ES256 algorithm (ECDSA with SHA-256)
      # -7 is ES256
      protected_header = %{1 => -7}
      protected_header_cbor = CBOR.encode(protected_header)

      sig_structure = ["Signature1", protected_header_cbor, <<>>, payload]
      sig_structure_cbor = CBOR.encode(sig_structure)

      with {:ok, raw_signature} <- sign_with_owner_key(sig_structure_cbor) do
        cose_sign1_array = [
          protected_header_cbor,
          %{},
          payload,
          raw_signature
        ]

        # Tag 18 is associated with COSE_Sign1
        cose_sign1 = %CBOR.Tag{tag: 18, value: cose_sign1_array}
        {:ok, cose_sign1}
      else
        {:error, reason} -> {:error, {:signing_error, reason}}
      end
    rescue
      e ->
        Logger.error("COSE_Sign1 build failed", error: inspect(e))
        {:error, {:cose_build_error, e}}
    end
  end

  def buildOwnerSignMessage(nonce) do
    with ov <- decode_ownership_voucher(),
         {:ok, to0d} <- build_to0d(ov, 3600, nonce),
         {:ok, to1dTo0dHash} <- buildto1dTo0dHash(to0d),
         {:ok, rv_entry1} <- build_rvto2addr_entry(CBOR.encode([]), "pippo", 8080, 3),
         {:ok, rv_entry2} <- build_rvto2addr_entry(CBOR.encode([]), "paperino", 8080, 3),
         {:ok, to1dRV} <- buildto1dRV([rv_entry1, rv_entry2]),
         {:ok, blob_payload} <- buildto1dBlobPayload(to1dRV, to1dTo0dHash),
         {:ok, signature} <- build_cose_sign1(blob_payload),
         to0_owner_sign_msg <- CBOR.encode([to0d, signature]) do
      {:ok, to0_owner_sign_msg}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end
end
