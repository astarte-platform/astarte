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

defmodule Astarte.Pairing.FDO.Rendezvous.OwnerSign.TO1D do
  @moduledoc """
  Module for handling the TO1D message in the FDO Rendezvous protocol, including encoding
  the message in the format expected by the protocol and signing it with the owner's key.
  """

  use TypedStruct

  alias Astarte.FDO.Hash
  alias Astarte.Pairing.FDO.Rendezvous.OwnerSign.TO1D
  alias Astarte.Pairing.FDO.Rendezvous.RvTO2Addr
  alias COSE.Messages.Sign1

  typedstruct do
    field :rv_to2_addr, [RvTO2Addr.t()]
    field :to0d_hash, Hash.t()
  end

  def encode(to1d) do
    %TO1D{rv_to2_addr: rv_to2_addr, to0d_hash: to0d_hash} = to1d
    rv = RvTO2Addr.encode_list(rv_to2_addr)
    to0d_hash = Hash.encode(to0d_hash)
    [rv, to0d_hash]
  end

  def encode_cbor(to1d) do
    encode(to1d)
    |> CBOR.encode()
  end

  def encode_sign(to1d, owner_key) do
    payload = encode_cbor(to1d) |> COSE.tag_as_byte()

    # TODO: choose alg based on key
    %Sign1{payload: payload, phdr: %{alg: :es256}, uhdr: %{}}
    |> Sign1.sign_encode(owner_key)
  end
end
