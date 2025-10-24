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

  # According to FDO spec 5.3.2: TO0.HelloAck = [NonceTO0Sign]
  def getNonceFromHelloAck(body) do
    case CBOR.decode(body) do
      {:ok, decoded, _rest} when is_list(decoded) and length(decoded) == 1 ->
        [nonce_to_sign] = decoded
        {:ok, nonce_to_sign}
      {:error, reason} ->
        Logger.warning("Failed to decode TO0.HelloAck CBOR", reason: reason)
        {:error, {:cbor_decode_error, reason}}
    end
  end
  
end
