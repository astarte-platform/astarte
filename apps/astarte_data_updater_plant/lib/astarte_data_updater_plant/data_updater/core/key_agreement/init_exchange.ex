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
#

defmodule Astarte.DataUpdaterPlant.DataUpdater.Core.KeyAgreement.InitExchange do
  @moduledoc """
  Represents the InitExchange key-agreement message exchanged over the
  `<realm>/<device>/control/keyAgreement` MQTT control topic.

  ## Message structure:

      [
        seq_num     :: uint,        # sequence number
        key_type    :: uint,        # suite identifier integer
        cose_key    :: #bstr,       # CBOR-encoded COSE_Key map
        hkdf_salt   :: #bstr,       # HKDF salt (32 B)
        nonce       :: #bstr        # AES-256-GCM nonce (12 B)
      ]

  """

  use TypedStruct

  alias COSE.Keys.ECC
  alias COSE.Keys.Key
  alias COSE.Keys.OKP

  # Ecto.Enum parameterized type for all supported key-agreement suites.
  # cast(type, integer) to {:ok, atom}   (encoded to decoded)
  # dump(type, atom) to {:ok, integer} (decoded to encoded)
  @key_suites Ecto.ParameterizedType.init(Ecto.Enum,
                values: [
                  ecdh_p256_hkdf_sha256_aes_256_gcm: 0,
                  ecdh_x25519_hkdf_sha256_aes_256_gcm: 1
                ]
              )
  # AES-256-GCM nonce size (bytes)
  @nonce_size 12
  # HKDF salt size (bytes)
  @hkdf_salt_size 32

  @typedoc """
  Internal atom representing a supported key-agreement suite.
  """
  @type key_suite ::
          :ecdh_x25519_hkdf_sha256_aes_256_gcm
          | :ecdh_p256_hkdf_sha256_aes_256_gcm

  typedstruct enforce: true do
    @typedoc "InitExchange key-agreement message."

    field :seq_num, non_neg_integer()
    field :key_type, key_suite()
    field :public_key, Key.t()
    field :hkdf_salt, binary()
    field :nonce, binary()
  end

  @doc """
  Builds a new `%InitExchange{}` with a freshly generated ephemeral X25519
  key pair, a random HKDF salt, a random AES-GCM nonce, and a random sequence
  number.

  Returns a `%InitExchange{}` with the full key struct stored in `public_key`
  (including the private `d` field for later ECDH derivation), a random HKDF
  salt, a random AES-GCM nonce, and a random `seq_num` suitable for
  correlation with the corresponding `ExchangeResp`.
  """
  @spec new(key_suite()) :: t()
  def new(key_type \\ :ecdh_x25519_hkdf_sha256_aes_256_gcm)

  def new(:ecdh_x25519_hkdf_sha256_aes_256_gcm) do
    key = OKP.generate(:enc)
    hkdf_salt = :crypto.strong_rand_bytes(@hkdf_salt_size)
    nonce = :crypto.strong_rand_bytes(@nonce_size)
    <<seq_num::unsigned-16>> = :crypto.strong_rand_bytes(2)

    %__MODULE__{
      seq_num: seq_num,
      key_type: :ecdh_x25519_hkdf_sha256_aes_256_gcm,
      public_key: key,
      hkdf_salt: hkdf_salt,
      nonce: nonce
    }
  end

  def new(:ecdh_p256_hkdf_sha256_aes_256_gcm) do
    key = ECC.generate(:es256)
    hkdf_salt = :crypto.strong_rand_bytes(@hkdf_salt_size)
    nonce = :crypto.strong_rand_bytes(@nonce_size)
    <<seq_num::unsigned-16>> = :crypto.strong_rand_bytes(2)

    %__MODULE__{
      seq_num: seq_num,
      key_type: :ecdh_p256_hkdf_sha256_aes_256_gcm,
      public_key: key,
      hkdf_salt: hkdf_salt,
      nonce: nonce
    }
  end

  @doc """
  Returns the list representation of an `%InitExchange{}` ready for CBOR encoding.
  """
  @spec encode(t()) :: list()
  def encode(%__MODULE__{} = msg) do
    {:ok, key_type_id} = Ecto.Type.dump(@key_suites, msg.key_type)
    cose_key_bytes = COSE.Keys.encode_cbor(msg.public_key)

    [
      msg.seq_num,
      key_type_id,
      %CBOR.Tag{tag: :bytes, value: cose_key_bytes},
      %CBOR.Tag{tag: :bytes, value: msg.hkdf_salt},
      %CBOR.Tag{tag: :bytes, value: msg.nonce}
    ]
  end

  @doc """
  CBOR-encodes an `%InitExchange{}` for transmission to the device.

  Returns the raw binary ready to be published on the MQTT control topic.
  """
  @spec cbor_encode(t()) :: binary()
  def cbor_encode(%__MODULE__{} = msg), do: encode(msg) |> CBOR.encode()

  @doc """
  Decodes and validates a raw CBOR payload received on the
  `control/keyAgreement` topic.
  """
  @spec decode(binary()) :: {:ok, t()} | {:error, atom()}
  def decode(payload) when is_binary(payload) do
    case CBOR.decode(payload) do
      {:ok, raw, _rest} -> parse(raw)
      {:error, _reason} -> {:error, :invalid_payload}
    end
  end

  defp parse([seq_num, key_type, public_key, hkdf_salt, nonce])
       when is_integer(seq_num) and seq_num >= 0 do
    with {:ok, key_suite} <- parse_key_suite(key_type),
         {:ok, cose_key_bytes} <- unwrap_bytes(public_key),
         {:ok, cose_key_map} <- decode_cbor(cose_key_bytes),
         {:ok, raw_public_key} <- decode_cose_key(key_suite, cose_key_map),
         {:ok, hkdf_salt} <- unwrap_bytes(hkdf_salt),
         :ok <- validate_hkdf_salt(hkdf_salt),
         {:ok, nonce} <- unwrap_bytes(nonce),
         :ok <- validate_nonce(nonce) do
      {:ok,
       %__MODULE__{
         seq_num: seq_num,
         key_type: key_suite,
         public_key: raw_public_key,
         hkdf_salt: hkdf_salt,
         nonce: nonce
       }}
    end
  end

  defp parse(_), do: {:error, :invalid_payload}

  defp decode_cose_key(key_suite, cose_key_map) do
    with {:ok, cose_key} <- COSE.Keys.decode(cose_key_map),
         :ok <- validate_key_suite_compatibility(key_suite, cose_key) do
      {:ok, cose_key}
    end
  end

  defp validate_key_suite_compatibility(:ecdh_x25519_hkdf_sha256_aes_256_gcm, %OKP{crv: :x25519}),
    do: :ok

  defp validate_key_suite_compatibility(:ecdh_p256_hkdf_sha256_aes_256_gcm, %ECC{crv: :p256}),
    do: :ok

  defp validate_key_suite_compatibility(_, _), do: {:error, :key_type_mismatch}

  defp unwrap_bytes(%CBOR.Tag{tag: :bytes, value: value}), do: {:ok, value}
  defp unwrap_bytes(_), do: {:error, :invalid_payload}

  defp decode_cbor(bytes) do
    case CBOR.decode(bytes) do
      {:ok, decoded, _rest} -> {:ok, decoded}
      {:error, _reason} -> {:error, :invalid_payload}
    end
  end

  defp parse_key_suite(int) when is_integer(int) do
    case Ecto.Type.cast(@key_suites, int) do
      {:ok, suite} -> {:ok, suite}
      _ -> {:error, :unsupported_key_type}
    end
  end

  defp parse_key_suite(_), do: {:error, :unsupported_key_type}

  defp validate_hkdf_salt(salt) when byte_size(salt) == @hkdf_salt_size, do: :ok
  defp validate_hkdf_salt(_), do: {:error, :invalid_hkdf_salt}

  defp validate_nonce(nonce) when byte_size(nonce) == @nonce_size, do: :ok
  defp validate_nonce(_), do: {:error, :invalid_nonce}

  @doc """
  Returns the Ecto.Enum parameterized type for all supported key-agreement
  suites. Use `Ecto.Type.cast/2` (integer to atom) and `Ecto.Type.dump/2`
  (atom to integer) to convert between encoded and decoded representations.
  """
  @spec supported_key_suites() :: term()
  def supported_key_suites, do: @key_suites
end
