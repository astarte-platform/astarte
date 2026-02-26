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

defmodule Astarte.Pairing.FDO.Types.Hash do
  use TypedStruct

  alias Astarte.Pairing.FDO.Types.Hash

  @type type() :: :sha256 | :sha384 | :hmac_sha256 | :hmac_sha384

  @sha256 -16
  @sha384 -43
  @hmac_sha256 5
  @hmac_sha384 6

  typedstruct do
    field :type, type()
    field :hash, binary()
  end

  def new(hash_type, value) when hash_type in [:sha256, :sha384] do
    hash = :crypto.hash(hash_type, value)
    %Hash{type: hash_type, hash: hash}
  end

  def new(:hmac_sha256, key, value), do: new_hmac(:sha256, key, value)
  def new(:hmac_sha384, key, value), do: new_hmac(:sha384, key, value)

  defp new_hmac(hmac_type, key, value) do
    hmac = :crypto.mac(:hmac, hmac_type, key.k, value)
    %Hash{type: hmac_type, hash: hmac}
  end

  def encode(hash) do
    %Hash{type: hash_type, hash: hash} = hash

    type_id = encode_type(hash_type)
    [type_id, COSE.tag_as_byte(hash)]
  end

  def encode_cbor(hash) do
    encode(hash)
    |> CBOR.encode()
  end

  def decode(cbor_list) do
    with [type, hash] <- cbor_list,
         {:ok, type} <- decode_type(type),
         %CBOR.Tag{tag: :bytes, value: hash} <- hash do
      hash =
        %Hash{
          type: type,
          hash: hash
        }

      {:ok, hash}
    else
      _ -> :error
    end
  end

  defp decode_type(type_int) do
    case type_int do
      @sha256 -> {:ok, :sha256}
      @sha384 -> {:ok, :sha384}
      @hmac_sha256 -> {:ok, :hmac_sha256}
      @hmac_sha384 -> {:ok, :hmac_sha384}
      _ -> :error
    end
  end

  defp encode_type(type) do
    case type do
      :sha256 -> @sha256
      :sha384 -> @sha384
      :hmac_sha256 -> @hmac_sha256
      :hmac_sha384 -> @hmac_sha384
    end
  end
end
