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

  @type sign_info :: {String.t(), binary()}

  typedstruct enforce: true do
    @typedoc "A hello device message structure."

    field :max_size, non_neg_integer()
    field :device_id, binary()
    field :nonce, binary()
    field :kex_name, String.t()
    field :cipher_name, String.t()
    field :easig_info, SignatureInfo.t()
  end

  def decode(cbor_binary) do
    with {:ok, message, _rest} <- CBOR.decode(cbor_binary),
         [max_size, device_id, nonce_hello_device, kex_name, cipher_name, easig_info] <- message,
         {:ok, easig_info} <- SignatureInfo.decode(easig_info) do
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
    else
      _ -> :error
    end
  end

  @doc false
  def generate do
    %HelloDevice{
      max_size: 1_000,
      device_id: Astarte.Core.Device.random_device_id(),
      nonce: :crypto.strong_rand_bytes(16),
      kex_name: "ECDH256",
      cipher_name: "A256GCM",
      easig_info: :es256
    }
  end
end
