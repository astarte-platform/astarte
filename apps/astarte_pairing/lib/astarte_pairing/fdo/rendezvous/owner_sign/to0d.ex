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

defmodule Astarte.Pairing.FDO.Rendezvous.OwnerSign.TO0D do
  use TypedStruct

  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias Astarte.Pairing.FDO.Rendezvous.OwnerSign.TO0D

  typedstruct do
    field :cbor_decoded_ownership_voucher, list()
    field :ownership_voucher, OwnershipVoucher.t()
    field :wait_seconds, non_neg_integer()
    field :nonce_to0_sign, binary()
  end

  def encode(to0d) do
    %TO0D{cbor_decoded_ownership_voucher: ov, wait_seconds: wait_seconds, nonce_to0_sign: nonce} =
      to0d

    nonce = COSE.tag_as_byte(nonce)

    [ov, wait_seconds, nonce]
  end

  def encode_cbor(to0d) do
    encode(to0d)
    |> CBOR.encode()
  end
end
