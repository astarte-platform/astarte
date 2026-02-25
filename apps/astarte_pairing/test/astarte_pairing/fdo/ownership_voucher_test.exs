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

defmodule Astarte.Pairing.FDO.OwnershipVoucherTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device

  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias Astarte.Pairing.FDO.OwnershipVoucher.Header
  alias Astarte.FDO.Hash
  alias Astarte.FDO.PublicKey
  alias Astarte.Pairing.Queries

  import Astarte.Helpers.FDO

  describe "handle ownership voucher," do
    test "save voucher data ", ctx do
      %{
        realm_name: realm_name,
        device: device
      } = ctx

      device_id = device.device_id

      assert :ok =
               OwnershipVoucher.save_voucher(
                 realm_name,
                 sample_voucher(),
                 device_id,
                 sample_private_key()
               )

      assert Queries.get_owner_private_key(realm_name, device_id)
    end
  end

  describe "decode_cbor/1" do
    test "decodes a valid cbor ownership voucher" do
      voucher = sample_cbor_voucher()

      assert {:ok, voucher} = OwnershipVoucher.decode_cbor(voucher)
      assert is_struct(voucher, OwnershipVoucher)
      assert is_binary(voucher.cert_chain |> hd())
      assert is_struct(voucher.hmac, Hash)
      assert is_struct(voucher.header, Header)
      assert is_struct(voucher.header.cert_chain_hash, Hash)
      assert is_struct(voucher.header.public_key, PublicKey)
      assert is_binary(voucher.header.guid)
      assert voucher.protocol_version == voucher.header.protocol_version
      assert {:ok, _} = COSE.Messages.Sign1.decode(voucher.entries |> hd())
    end
  end
end
