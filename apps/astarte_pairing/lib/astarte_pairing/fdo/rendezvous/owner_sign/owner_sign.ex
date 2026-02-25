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

defmodule Astarte.Pairing.FDO.Rendezvous.OwnerSign do
  use TypedStruct

  alias Astarte.FDO.Hash
  alias Astarte.Pairing.FDO.Rendezvous.OwnerSign
  alias Astarte.Pairing.FDO.Rendezvous.OwnerSign.TO0D
  alias Astarte.Pairing.FDO.Rendezvous.OwnerSign.TO1D

  typedstruct do
    field :to0d, TO0D.t()
    field :to1d, TO1D.t()
  end

  def encode_sign_with_hash(owner_sign, owner_key) do
    %OwnerSign{to0d: to0d, to1d: to1d} = owner_sign
    to0d = TO0D.encode_cbor(to0d)

    to0d_hash = Hash.new(:sha256, to0d)
    to1d = %{to1d | to0d_hash: to0d_hash}
    to1d = TO1D.encode_sign(to1d, owner_key)

    [to0d, to1d]
  end

  def encode_sign_cbor_with_hash(owner_sign, owner_key) do
    encode_sign_with_hash(owner_sign, owner_key)
    |> CBOR.encode()
  end
end
