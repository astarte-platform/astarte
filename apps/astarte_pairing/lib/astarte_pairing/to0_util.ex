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

  alias Astarte.Pairing.MockFDOApi

  @doc """
  Decodes the TO0.HelloAck CBOR body and returns the extracted nonce.
  """
  def get_nonce_from_hello_ack(body) do
    Logger.debug("Decoding TO0.HelloAck CBOR body: #{inspect(body)}")

    case CBOR.decode(body) do
      {:ok, [%CBOR.Tag{tag: :bytes, value: nonce}], _rest}
      when is_binary(nonce) and byte_size(nonce) == 16 ->
        {:ok, nonce}

      {:ok, [%CBOR.Tag{tag: :bytes, value: nonce}], _rest}
      when is_binary(nonce) and byte_size(nonce) != 16 ->
        {:error, {:wrong_cbor_size, nonce}}

      {:ok, decoded, _rest} ->
        {:error, {:unexpected_body_format, decoded}}

      {:error, reason} ->
        {:error, {:cbor_decode_error, reason}}
    end
  end

  def get_ownership_voucher() do
    MockFDOApi.get_ownership_voucher()
  end

  def decode_ownership_voucher(voucher_pem) do
    ov_data =
      voucher_pem
      |> String.replace("-----BEGIN OWNERSHIP VOUCHER-----", "")
      |> String.replace("-----END OWNERSHIP VOUCHER-----", "")
      |> String.replace(~r/\s/, "")

    with {:ok, cbor_data} <- Base.decode64(ov_data),
         {:ok, result, _rest} <- CBOR.decode(cbor_data) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
      other -> {:error, "PEM parsing failed: #{inspect(other)}"}
    end
  end

  def get_owner_private_key() do
    MockFDOApi.get_owner_private_key()
  end

  def sign_with_owner_key(data, owner_key) do
    case :public_key.pem_decode(owner_key) do
      [{:ECPrivateKey, der_data, :not_encrypted}] ->
        with {:ok, ec_private_key} <- safe_der_decode(der_data),
             {:ok, raw_priv} <- extract_raw_private_key(ec_private_key),
             {:ok, signature} <- safe_sign(data, raw_priv) do
          {:ok, signature}
        else
          {:error, reason} ->
            Logger.error("Signing failed", error: inspect(reason))
            {:error, reason}
        end

      _ ->
        Logger.error("PEM decode failed for owner key")
        {:error, :pem_decode_failed}
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
    rv_entry = [ip, dns, port, protocol]
    encoded_entry = CBOR.encode([rv_entry])
    {:ok, encoded_entry}
  end

  defp build_to1d_rv(entries) do
    to1d_rv = CBOR.encode([entries])
    {:ok, to1d_rv}
  end

  defp build_to0d(ov, wait_seconds, nonce) do
    to0d = CBOR.encode([ov, wait_seconds, add_cbor_tag(nonce)])
    {:ok, to0d}
  end

  defp add_cbor_tag(payload) do
    %CBOR.Tag{tag: :bytes, value: payload}
  end

  defp build_to1d_to0d_hash(to0d) do
    to1d_to0d_hash_value = :crypto.hash(:sha256, to0d)
    # 47 is the key for SHA-256
    to1d_to0d_hash = CBOR.encode([47, to1d_to0d_hash_value])
    {:ok, to1d_to0d_hash}
  end

  defp build_to1d_blob_payload(to1d_rv, to1d_to0d_hash) do
    blob_payload = CBOR.encode([to1d_rv, to1d_to0d_hash])
    {:ok, blob_payload}
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
        add_cbor_tag(protected_header_cbor),
        %{},
        add_cbor_tag(payload),
        add_cbor_tag(raw_signature)
      ]

      # Tag 18 is associated with COSE_Sign1
      cose_sign1 = %CBOR.Tag{tag: 18, value: cose_sign1_array}
      {:ok, cose_sign1}
    else
      {:error, reason} -> {:error, {:signing_error, reason}}
    end
  end

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
         {:ok, signature} <- build_cose_sign1(blob_payload, owner_key) do
      result = CBOR.encode([add_cbor_tag(to0d), signature])
      Logger.debug("build_owner_sign_message success: #{inspect(result)}")
      {:ok, result}
    else
      error ->
        Logger.debug("build_owner_sign_message error: #{inspect(error)}")
        {:error, error}
    end
  end
end
