#
# This file is part of Astarte.
#
# Copyright 2017 Ispirata Srl
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

defmodule Astarte.Core.Device do
  @moduledoc """
  Utility functions to deal with Astarte devices
  """

  @type device_id :: <<_::128>>
  @type encoded_device_id :: String.t()

  @doc """
  Decodes a Base64 url encoded device id and returns it as a 128-bit binary (usable as uuid).

  By default, it will fail with `{:error, :extended_id_not_allowed}` if the size of the encoded device_id is > 128 bit.
  You can pass `allow_extended_id: true` as second argument to allow longer device ids (the returned binary will still be 128 bit long, but the function will not return an error and will instead drop the extended id).

  Returns `{:ok, device_id}` or `{:error, reason}`.
  """
  @spec decode_device_id(encoded_device_id :: encoded_device_id(), opts :: options) ::
          {:ok, device_id :: device_id()} | {:error, atom()}
        when options: [option],
             option: {:allow_extended_id, boolean()}
  def decode_device_id(encoded_device_id, opts \\ [])
      when is_binary(encoded_device_id) and is_list(opts) do
    allow_extended = Keyword.get(opts, :allow_extended_id, false)

    with {:ok, device_id, extended_id} <- decode_extended_device_id(encoded_device_id) do
      if not allow_extended and byte_size(extended_id) > 0 do
        {:error, :extended_id_not_allowed}
      else
        {:ok, device_id}
      end
    end
  end

  @doc """
  Decodes an extended Base64 url encoded device id.

  Returns `{:ok, device_id, extended_id}` (where `device_id` is a binary with the first 128 bits of the decoded id and `extended_id` the rest of the decoded binary) or `{:error, reason}`.
  """
  @spec decode_extended_device_id(encoded_device_id :: encoded_device_id()) ::
          {:ok, device_id :: device_id(), extended_id :: binary()} | {:error, atom()}
  def decode_extended_device_id(encoded_device_id) when is_binary(encoded_device_id) do
    with {:ok, decoded} <- Base.url_decode64(encoded_device_id, padding: false),
         <<device_id::binary-size(16), extended_id::binary>> <- decoded do
      {:ok, device_id, extended_id}
    else
      _ ->
        {:error, :invalid_device_id}
    end
  end

  @doc """
  Encodes a device id with the standard encoding (Base64 url encoding, no padding). The device id must be exactly 16 bytes (128 bits) long.

  Returns the encoded device id.
  """
  @spec encode_device_id(device_id :: device_id()) :: encoded_device_id :: encoded_device_id()
  def encode_device_id(device_id) when is_binary(device_id) and byte_size(device_id) == 16 do
    Base.url_encode64(device_id, padding: false)
  end

  @doc """
  Generate a random Astarte device id.

  The generated device id is also a valid UUID v4.
  """
  @spec random_device_id :: device_id :: device_id()
  def random_device_id do
    <<u0::48, _::4, u1::12, _::2, u2::62>> = :crypto.strong_rand_bytes(16)
    <<u0::48, 4::4, u1::12, 2::2, u2::62>>
  end
end
