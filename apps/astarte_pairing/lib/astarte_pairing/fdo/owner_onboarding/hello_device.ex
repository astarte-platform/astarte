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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice do
  @moduledoc """
  HelloDevice structure as per FDO specification.
  """
  use TypedStruct

  alias Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice
  alias Astarte.Pairing.FDO.OwnerOnboarding.SignatureInfo

  require Logger

  @type sign_info :: {String.t(), binary()}

  @allowed_ciphers [
    :aes_128_gcm,
    :aes_192_gcm,
    :aes_256_gcm,
    :aes_ccm_16_64_128,
    :aes_ccm_16_64_256,
    :aes_ccm_64_64_128,
    :aes_ccm_64_64_256,
    :aes_ccm_16_128_128,
    :aes_ccm_16_128_256,
    :aes_ccm_64_128_128,
    :aes_ccm_64_128_256,
    :aes_128_cbc,
    :aes_128_ctr,
    :aes_256_cbc,
    :aes_256_ctr
  ]

  @allowed_kex_names [
    "DHKEXid14",
    "DHKEXid15",
    "ASYMKEX2048",
    "ASYMKEX3072",
    "ECDH256",
    "ECDH384"
  ]

  @type cipher ::
          :aes_128_gcm
          | :aes_192_gcm
          | :aes_256_gcm
          | :aes_ccm_16_64_128
          | :aes_ccm_16_64_256
          | :aes_ccm_64_64_128
          | :aes_ccm_64_64_256
          | :aes_ccm_16_128_128
          | :aes_ccm_16_128_256
          | :aes_ccm_64_128_128
          | :aes_ccm_64_128_256
          | :aes_128_cbc
          | :aes_128_ctr
          | :aes_256_cbc
          | :aes_256_ctr

  @typedoc "Allowed values: DHKEXid14, DHKEXid15, ASYMKEX2048, ASYMKEX3072, ECDH256, ECDH384"
  @type kex_name :: String.t()

  typedstruct enforce: true do
    @typedoc "A hello device message structure."

    field :max_size, non_neg_integer()
    field :device_id, binary()
    field :nonce, binary()
    field :kex_name, kex_name()
    field :cipher_name, cipher()
    field :easig_info, SignatureInfo.t()
  end

  def decode(cbor_binary) do
    with {:ok, message, _rest} <- cbor_decode(cbor_binary),
         {:ok, hello_device} <- parse_hello_device(message) do
      {:ok, hello_device}
    end
  end

  defp cbor_decode(cbor_binary) do
    case CBOR.decode(cbor_binary) do
      {:ok, message, rest} -> {:ok, message, rest}
      _ -> {:error, :message_body_error}
    end
  end

  defp decode_kex_name(kex_name) do
    if kex_name in @allowed_kex_names do
      {:ok, kex_name}
    else
      "hello device: received #{inspect(kex_name)} as kex_name"
      |> Logger.error()

      {:error, :invalid_message}
    end
  end

  defp parse_hello_device([
         max_size,
         %CBOR.Tag{tag: :bytes, value: device_id},
         %CBOR.Tag{tag: :bytes, value: nonce_hello_device},
         kex_name,
         cipher_name,
         easig_info
       ]) do
    with {:ok, kex_name_str} <- decode_kex_name(kex_name),
         {:ok, easig_info} <- SignatureInfo.decode(easig_info),
         {:ok, cipher} <- decode_cipher(cipher_name) do
      {:ok,
       %HelloDevice{
         max_size: max_size,
         device_id: device_id,
         nonce: nonce_hello_device,
         kex_name: kex_name_str,
         cipher_name: cipher,
         easig_info: easig_info
       }}
    else
      _ ->
        {:error, :message_body_error}
    end
  end

  defp parse_hello_device(_), do: {:error, :message_body_error}

  @doc false
  def generate do
    %HelloDevice{
      max_size: 1_000,
      device_id: Astarte.Core.Device.random_device_id(),
      nonce: :crypto.strong_rand_bytes(16),
      kex_name: "ECDH256",
      cipher_name: :aes_256_gcm,
      easig_info: :es256
    }
  end

  defp decode_cipher(cipher) do
    case COSE.algorithm_from_id(cipher) do
      cipher when cipher in @allowed_ciphers ->
        {:ok, cipher}

      bad_cipher ->
        "hello device: received #{inspect(bad_cipher)} as cipher"
        |> Logger.error()

        {:error, :invalid_message}
    end
  end
end
