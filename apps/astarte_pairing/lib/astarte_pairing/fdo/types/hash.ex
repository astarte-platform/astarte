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

  typedstruct do
    field :type, type()
    field :hash, binary()
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
      -16 -> {:ok, :sha256}
      -43 -> {:ok, :sha384}
      5 -> {:ok, :hmac_sha256}
      6 -> {:ok, :hmac_sha384}
      _ -> :error
    end
  end
end
