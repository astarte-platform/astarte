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

  @doc """
  Decodes the TO0.HelloAck CBOR body and returns the extracted nonce.
  """
  def get_nonce_from_hello_ack(body) do
    Logger.info("Decoding TO0.HelloAck CBOR body: #{inspect(body)}")

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
end
