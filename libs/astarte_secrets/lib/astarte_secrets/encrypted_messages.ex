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

  alias COSE.Messages.Encrypt0
  require Logger

  @doc """
  Encrypts device data wrapping it into a COSE binary payload.
  The `key_type` represents the cipher suite determined during the handshake (e.g., :aes_128_gcm, :aes_256_gcm).
  """
  @spec encrypt(binary(), binary(), atom()) :: binary()
  def encrypt(plaintext, session_key, key_type) do
    iv = :crypto.strong_rand_bytes(12)
    uhdr = %{iv: iv}
    msg = Encrypt0.build(plaintext, %{}, uhdr)
    key = %{k: session_key}

    Encrypt0.encrypt_encode(msg, key_type, key, iv)
  end

  @doc """
  Decrypts a COSE Encrypt0 binary payload using the shared `session_key`.
  The `key_type` represents the cipher suite determined during the handshake (e.g., :aes_128_gcm, :aes_256_gcm).
  """
  @spec decrypt(binary(), binary(), atom()) :: {:ok, binary()} | {:error, atom()}
  def decrypt(cbor_binary, session_key, key_type) do
    key = %{k: session_key}

    with {:ok, msg} <- Encrypt0.decode_cbor(cbor_binary),
         iv when is_binary(iv) <- msg.uhdr.iv,
         {:ok, decrypted_msg} <- Encrypt0.decrypt(msg, key_type, key, iv) do
      {:ok, decrypted_msg.payload}
    else
      error ->
        Logger.warning(
          "Rejected invalid or malformed device data during decryption: #{inspect(error)}"
        )

        {:error, :decryption_failed}
    end
  end
end
