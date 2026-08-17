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

defmodule Astarte.Secrets.EncryptedMessages do
  @moduledoc """
  Provides functions to encrypt and decrypt device data payloads using
  the COSE Encrypt0 standard.
  """

  alias COSE.Keys.Symmetric
  alias COSE.Messages.Encrypt0
  require Logger

  @doc """
  Encrypts device data wrapping it into a COSE binary payload, using the
  given symmetric COSE key. The key's `alg` field is the cipher suite
  determined during the handshake (e.g., :aes_128_gcm, :aes_256_gcm).
  """
  @spec encrypt(binary(), Symmetric.t()) :: binary()
  def encrypt(plaintext, %Symmetric{} = symmetric_key) do
    iv = :crypto.strong_rand_bytes(12)
    uhdr = %{iv: COSE.tag_as_byte(iv)}
    msg = Encrypt0.build(plaintext, %{}, uhdr)

    Encrypt0.encrypt_encode(msg, symmetric_key.alg, symmetric_key, iv)
  end

  @doc """
  Decrypts a COSE Encrypt0 binary payload using the given symmetric COSE key.
  The key's `alg` field is the cipher suite determined during the handshake
  (e.g., :aes_128_gcm, :aes_256_gcm).
  """
  @spec decrypt(binary(), Symmetric.t()) :: {:ok, binary()} | {:error, atom()}
  def decrypt(cbor_binary, %Symmetric{} = symmetric_key) do
    case Encrypt0.decrypt_decode(cbor_binary, symmetric_key.alg, symmetric_key) do
      {:ok, decrypted_msg} ->
        {:ok, decrypted_msg.payload}

      error ->
        Logger.warning(
          "Rejected invalid or malformed device data during decryption: #{inspect(error)}"
        )

        {:error, :decryption_failed}
    end
  end
end
