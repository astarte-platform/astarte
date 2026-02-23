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

defmodule Astarte.Pairing.FDO.Types.PublicKey do
  use TypedStruct

  alias Astarte.Pairing.FDO.Types.PublicKey

  @type type() :: :rsa2048restr | :rsapkcs | :rsapss | :secp256r1 | :secp384r1
  @type encoding() :: :crypto | :x509 | :x5chain | :cosekey

  typedstruct do
    field :type, type()
    field :encoding, encoding()
    field :body, binary() | [binary()]
  end

  def decode_cbor(cbor_binary) do
    with {:ok, cbor_list, ""} <- CBOR.decode(cbor_binary),
         {:ok, public_key} <- decode(cbor_list) do
      {:ok, public_key}
    else
      _ -> :error
    end
  end

  def decode(cbor_list) do
    with [type, enc, body] <- cbor_list,
         {:ok, type} <- decode_type(type),
         {:ok, enc} <- decode_encoding(enc),
         {:ok, body} <- parse_body(enc, body) do
      public_key =
        %PublicKey{
          type: type,
          encoding: enc,
          body: body
        }

      {:ok, public_key}
    else
      _ -> :error
    end
  end

  defp parse_body(:x5chain, body) when is_list(body) do
    cert_chain =
      Enum.map(body, fn
        %CBOR.Tag{tag: :bytes, value: val} -> {:ok, val}
        _ -> :error
      end)

    with :ok <- Enum.find(cert_chain, :ok, &(&1 == :error)) do
      res = Enum.map(cert_chain, fn {:ok, cert} -> cert end)
      {:ok, res}
    end
  end

  defp parse_body(_, body) do
    case body do
      %CBOR.Tag{tag: :bytes, value: val} -> {:ok, val}
      _ -> :error
    end
  end

  defp decode_type(type_int) do
    case type_int do
      1 -> {:ok, :rsa2048restr}
      5 -> {:ok, :rsapkcs}
      6 -> {:ok, :rsapss}
      10 -> {:ok, :secp256r1}
      11 -> {:ok, :secp384r1}
      _ -> :error
    end
  end

  defp decode_encoding(enc_int) do
    case enc_int do
      0 -> {:ok, :crypto}
      1 -> {:ok, :x509}
      2 -> {:ok, :x5chain}
      3 -> {:ok, :cosekey}
      _ -> :error
    end
  end

  def encode_cbor(%PublicKey{} = pk) do
    pk |> encode() |> CBOR.encode()
  end

  def encode(%PublicKey{} = pk) do
    %PublicKey{
      type: type,
      encoding: enc,
      body: body
    } = pk

    cbor_type = encode_type(type)
    cbor_encoding = encode_encoding(enc)
    cbor_body = encode_body(enc, body)

    [cbor_type, cbor_encoding, cbor_body]
  end

  defp encode_body(:x5chain, body) do
    Enum.map(body, &COSE.tag_as_byte/1)
  end

  defp encode_body(_, body), do: COSE.tag_as_byte(body)

  defp encode_type(type) do
    case type do
      :rsa2048restr -> 1
      :rsapkcs -> 5
      :rsapss -> 6
      :secp256r1 -> 10
      :secp384r1 -> 11
    end
  end

  defp encode_encoding(encoding) do
    case encoding do
      :crypto -> 0
      :x509 -> 1
      :x5chain -> 2
      :cosekey -> 3
    end
  end
end
