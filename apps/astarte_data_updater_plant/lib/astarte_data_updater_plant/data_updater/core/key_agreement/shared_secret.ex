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
# SPDX-License-Identifier: Apache-2.0

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.SharedSecret do
  @moduledoc """
  Handles ECDH shared secret derivation and HKDF expansion using COSE Keys.
  Requires the `hkdf` hex package.
  """

  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.ExchangeFailed
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.ExchangeResp
  alias Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.InitExchange
  alias COSE.Keys.ECC
  alias COSE.Keys.OKP
  alias COSE.Keys.Symmetric

  @hkdf_info "astarte-kdf"
  @x25519_key_size 32
  @p256_coordinate_size 32

  @doc """
  Derives a 256-bit AES-GCM symmetric key using the given COSE keys and salt.
  Supports both X25519 (OKP) and P-256 (ECC).
  """
  @spec derive(InitExchange.t(), ExchangeResp.t()) ::
          {:ok, Symmetric.t()} | {:error, ExchangeFailed.reason(), String.t()}
  def derive(%InitExchange{} = init_exchange, %ExchangeResp{} = exchange_resp) do
    case compute_ecdh(exchange_resp.public_key, init_exchange.public_key) do
      {:ok, raw_ecdh_secret} ->
        # Extract the pseudo-random key (PRK)
        prk = HKDF.extract(:sha256, raw_ecdh_secret, init_exchange.hkdf_salt)

        # Expand to exactly 32 bytes (256 bits)
        final_key = HKDF.expand(:sha256, prk, 32, @hkdf_info)

        {:ok, %Symmetric{alg: symmetric_alg(init_exchange.key_type), k: final_key}}

      {:error, :key_mismatch_or_unsupported} ->
        {:error, :unprocessable_entity, "unsupported or mismatched key"}

      {:error, {:ecdh_failed, _detail}} ->
        {:error, :unprocessable_entity, "key derivation failed"}
    end
  end

  # Both currently supported suites use AES-256-GCM as their symmetric cipher.
  defp symmetric_alg(:ecdh_x25519_hkdf_sha256_aes_256_gcm), do: :aes_256_gcm
  defp symmetric_alg(:ecdh_p256_hkdf_sha256_aes_256_gcm), do: :aes_256_gcm

  # X25519
  defp compute_ecdh(
         %OKP{crv: :x25519, d: my_priv},
         %OKP{crv: :x25519, x: <<peer_pub::binary-size(@x25519_key_size)>>}
       ) do
    safe_compute_key(peer_pub, my_priv, :x25519)
  end

  # P-256 (secp256r1)
  defp compute_ecdh(
         %ECC{crv: :p256, d: my_priv},
         %ECC{
           crv: :p256,
           x: <<peer_x::binary-size(@p256_coordinate_size)>>,
           y: <<peer_y::binary-size(@p256_coordinate_size)>>
         }
       ) do
    # Erlang expects the public key as an uncompressed point format: <<4, x, y>>
    uncompressed_pub = <<0x04, peer_x::binary, peer_y::binary>>
    safe_compute_key(uncompressed_pub, my_priv, :secp256r1)
  end

  defp compute_ecdh(_, _), do: {:error, :key_mismatch_or_unsupported}

  defp safe_compute_key(peer_pub, my_priv, curve) do
    {:ok, :crypto.compute_key(:ecdh, peer_pub, my_priv, curve)}
  rescue
    e -> {:error, {:ecdh_failed, Exception.message(e)}}
  end
end
