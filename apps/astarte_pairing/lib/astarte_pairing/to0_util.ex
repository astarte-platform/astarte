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

  def get_nonce_from_hello_ack(body) do
    case CBOR.decode(body) do
      {:ok, [nonce_to_sign], _rest} when is_binary(nonce_to_sign) and byte_size(nonce_to_sign) == 16 ->
        {:ok, nonce_to_sign}
      {:ok, [nonce_to_sign], _rest} when is_binary(nonce_to_sign) and byte_size(nonce_to_sign) != 16 ->
        {:error, {:unexpected_binary, nonce_to_sign}}
      {:ok, decoded, _rest} ->
        {:error, {:unexpected_cbor_format, decoded}}
     
      {:error, reason} ->
        Logger.warning("Failed to decode TO0.HelloAck CBOR", reason: reason)
        {:error, {:cbor_decode_error, reason}}
    end
  end
  # TODO: real implementation using API call
  def get_ownership_voucher() do
    path = Path.join([:code.priv_dir(:astarte_pairing), "ownership-voucher.pem"])
    case File.read(path) do
      {:ok, content} ->
        {:ok, content}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def decode_ownership_voucher(ownership_voucher) do
    with ov_data <- ownership_voucher
                    |> String.replace(~r/-----BEGIN OWNERSHIP VOUCHER-----|-----END OWNERSHIP VOUCHER-----|\s/, ""),
         {:ok, cbor_data} <- Base.decode64(ov_data),
         {:ok, result, _rest} <- CBOR.decode(cbor_data) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:error, :invalid_ownership_voucher_format}
    end
  end

  # TODO: real implementation using API call
  def get_owner_private_key() do
    path = Path.join([:code.priv_dir(:astarte_pairing), "owner-key.pem"])

    case File.read(path) do
      {:ok, content} ->
        {:ok, content}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def sign_with_owner_key(data, owner_key) do
    with [{:ECPrivateKey, der_data, :not_encrypted}] <- :public_key.pem_decode(owner_key),
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

  def safe_der_decode(der_data) do
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

  def safe_sign(data, priv_key) do
    # ECDSA with SHA-256 requires a 32-byte private key secp256r1
    if is_binary(priv_key) and byte_size(priv_key) == 32 do
      try do
        {:ok, :crypto.sign(:ecdsa, :sha256, data, [priv_key, :secp256r1])}
      rescue
        e -> {:error, {:signing_failed, e}}
      end
    else
      {:error, :invalid_private_key_format}
  end
end

  def build_rv_to2_addr_entry(ip, dns, port, protocol) do
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

  defp build_to1d_rv(entries) do
    with to1d_rv <- CBOR.encode([entries]) do
      {:ok, to1d_rv}
    end
  end

  defp build_to0d(ov, wait_seconds, nonce) do
    with to0d <- CBOR.encode([ov, wait_seconds, nonce]) do
      {:ok, to0d}
    end
  end

  defp tag_to0d(to0d) do
    %CBOR.Tag{tag: :bytes, value: to0d} 
  end

  defp build_to1d_to0d_hash(to0d) do
    with to1d_to0d_hash_value <- :crypto.hash(:sha256, to0d),
         # 47 is the key for SHA-256
         to1d_to0d_hash <- CBOR.encode([47, to1d_to0d_hash_value]) do
          {:ok, to1d_to0d_hash} 
    end
  end

  defp build_to1d_blob_payload(to1d_rv, to1d_to0d_hash) do
    with blob_payload <- CBOR.encode([to1d_rv, to1d_to0d_hash]) do
      {:ok, blob_payload}
    end
  end

  def build_cose_sign1(payload, owner_key) do
      # Protected header: ES256 algorithm (ECDSA with SHA-256)
      # -7 is ES256
      protected_header = %{1 => -7}
      protected_header_cbor = CBOR.encode(protected_header)

      sig_structure = ["Signature1", protected_header_cbor, <<>>, payload]
      sig_structure_cbor = CBOR.encode(sig_structure)

      with {:ok, raw_signature} <- sign_with_owner_key(sig_structure_cbor, owner_key) do
        cose_sign1_array = [
          %CBOR.Tag{tag: :bytes, value: protected_header_cbor},
          %{},
          %CBOR.Tag{tag: :bytes, value: payload},
          %CBOR.Tag{tag: :bytes, value: raw_signature}
        ]

        # Tag 18 is associated with COSE_Sign1
        cose_sign1 = %CBOR.Tag{tag: 18, value: cose_sign1_array}
        {:ok, cose_sign1}
      else
        {:error, reason} -> {:error, {:signing_error, reason}}
      end
  end

  # TODO: real implementation using API call
  def get_astarte_rv_to2_addr_entries() do
    with {:ok, rv_entry1} <- build_rv_to2_addr_entry(CBOR.encode([]), "pippo", 8080, 3),
         {:ok, rv_entry2} <- build_rv_to2_addr_entry(CBOR.encode([]), "paperino", 8080, 3) do
      {:ok, [rv_entry1, rv_entry2]}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def build_owner_sign_message(ownership_voucher, owner_key, nonce, addr_entries) do
    with {:ok, decoded_ownership_voucher} <- decode_ownership_voucher(ownership_voucher),
         {:ok, to0d} <- build_to0d(decoded_ownership_voucher, 3600, nonce),
         {:ok, to1d_to0d_hash} <- build_to1d_to0d_hash(to0d),
         {:ok, to1d_rv} <- build_to1d_rv(addr_entries),
         {:ok, blob_payload} <- build_to1d_blob_payload(to1d_rv, to1d_to0d_hash),
         {:ok, signature} <- build_cose_sign1(blob_payload, owner_key),
         {:ok, to0_owner_sign_msg} <- CBOR.encode([tag_to0d(to0d), signature]) do
      {:ok, to0_owner_sign_msg}
    else
      {:error, reason} ->
        {:error, reason}
    end
  end
end