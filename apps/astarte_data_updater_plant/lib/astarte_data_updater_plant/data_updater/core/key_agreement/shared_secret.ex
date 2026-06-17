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

  alias COSE.Keys.ECC
  alias COSE.Keys.OKP

  @hkdf_info "astarte-kdf"
  @x25519_key_size 32
  @p256_coordinate_size 32

  @doc """
  Derives a 256-bit AES-GCM symmetric key using the given COSE keys and salt.
  Supports both X25519 (OKP) and P-256 (ECC).
  """
  def derive(my_cose_key, peer_cose_key, salt) do
    with {:ok, raw_ecdh_secret} <- compute_ecdh(my_cose_key, peer_cose_key) do
      # Extract the pseudo-random key (PRK)
      prk = HKDF.extract(:sha256, raw_ecdh_secret, salt)

      # Expand to exactly 32 bytes (256 bits) for AES-256-GCM
      final_key = HKDF.expand(:sha256, prk, 32, @hkdf_info)

      {:ok, final_key}
    end
  end

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
