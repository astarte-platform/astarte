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

defmodule Astarte.Pairing.FDO.OwnershipVoucher.Header do
  use TypedStruct

  alias Astarte.Pairing.FDO.Types.PublicKey
  alias Astarte.Pairing.FDO.Types.Hash
  alias Astarte.Pairing.FDO.OwnershipVoucher.Header

  # TODO: rendezvous_info type
  typedstruct do
    field :protocol_version, :integer
    field :guid, binary()
    field :rendezvous_info, list()
    field :device_info, binary()
    field :public_key, PublicKey.t()
    field :cert_chain_hash, Hash.t() | nil
  end

  def decode_cbor(cbor) do
    case CBOR.decode(cbor) do
      {:ok, message, _} -> decode(message)
      _ -> :error
    end
  end

  def decode(cbor_list) do
    with [protocol, guid, rendezvous_info, device_info, pub_key, cert_chain_hash] <- cbor_list,
         {:ok, public_key} <- PublicKey.decode(pub_key),
         {:ok, cert_chain_hash} <- decode_cert_chain_hash(cert_chain_hash),
         %CBOR.Tag{tag: :bytes, value: guid} <- guid do
      header =
        %Header{
          protocol_version: protocol,
          guid: guid,
          rendezvous_info: rendezvous_info,
          device_info: device_info,
          public_key: public_key,
          cert_chain_hash: cert_chain_hash
        }

      {:ok, header}
    else
      _ -> :error
    end
  end

  defp decode_cert_chain_hash(cert_chain_hash) do
    case cert_chain_hash do
      nil -> {:ok, nil}
      hash -> Hash.decode(hash)
    end
  end
end
