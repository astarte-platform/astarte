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
    field :body, binary()
  end

  def decode(cbor_list) do
    with [type, enc, body] <- cbor_list,
         {:ok, type} <- decode_type(type),
         {:ok, enc} <- decode_encoding(enc),
         %CBOR.Tag{tag: :bytes, value: body} <- body do
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
end
