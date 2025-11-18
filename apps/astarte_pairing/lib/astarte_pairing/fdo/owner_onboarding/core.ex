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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.Core do
  alias Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice

  def decode_hello_device(cbor_hello_device) do
    case CBOR.decode(cbor_hello_device) do
      {:ok, decoded_hello_device, ""} ->
        parse_hello_device(decoded_hello_device)

      _ ->
        {:error, :invalid_hello_device_message}
    end
  end

  defp parse_hello_device(decoded_hello_device) do
    case decoded_hello_device do
      [max_size, device_id, nonce_hello_device, kex_name, cipher_name, easig_info] ->
        hello_device =
          %HelloDevice{
            max_size: max_size,
            device_id: device_id,
            nonce: nonce_hello_device,
            kex_name: kex_name,
            cipher_name: cipher_name,
            easig_info: easig_info
          }

        {:ok, hello_device}

      _ ->
        {:error, :invalid_hello_device_format}
    end
  end
end
