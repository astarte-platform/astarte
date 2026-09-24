#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.FDO.Core.Rendezvous.OwnerSignTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.Rendezvous.OwnerSign
  alias Astarte.FDO.Core.Rendezvous.OwnerSign.TO0D
  alias Astarte.FDO.Core.Rendezvous.OwnerSign.TO1D
  alias Astarte.FDO.Core.Rendezvous.RvTO2Addr
  alias COSE.Keys.ECC

  defp build_owner_sign do
    to0d = %TO0D{
      cbor_decoded_ownership_voucher: [1, 2, 3],
      wait_seconds: 3600,
      nonce_to0_sign: :crypto.strong_rand_bytes(16)
    }

    to1d = %TO1D{
      rv_to2_addr: [
        %RvTO2Addr{ip: nil, dns: "owner.example.com", port: 8042, protocol: :https}
      ],
      # to0d_hash is computed inside encode_sign_with_hash, so nil is fine here
      to0d_hash: nil
    }

    %OwnerSign{to0d: to0d, to1d: to1d}
  end

  describe "encode_sign_with_hash/2" do
    setup do
      %{key: ECC.generate(:es256)}
    end

    test "returns {:ok, [bstr, signed_to1d]}", %{key: key} do
      owner_sign = build_owner_sign()
      assert {:ok, [bstr, to1d_signed]} = OwnerSign.encode_sign_with_hash(owner_sign, key)
      assert %CBOR.Tag{tag: :bytes} = bstr
      assert %CBOR.Tag{} = to1d_signed
    end

    test "each call produces a different to0d bstr (different nonce)", %{key: key} do
      a = build_owner_sign()
      b = build_owner_sign()
      {:ok, [bstr_a, _]} = OwnerSign.encode_sign_with_hash(a, key)
      {:ok, [bstr_b, _]} = OwnerSign.encode_sign_with_hash(b, key)
      assert bstr_a.value != bstr_b.value
    end
  end

  describe "encode_sign_cbor_with_hash/2" do
    setup do
      %{key: ECC.generate(:es256)}
    end

    test "returns {:ok, binary}", %{key: key} do
      owner_sign = build_owner_sign()
      assert {:ok, cbor_binary} = OwnerSign.encode_sign_cbor_with_hash(owner_sign, key)
      assert is_binary(cbor_binary)
    end

    test "result is valid CBOR", %{key: key} do
      owner_sign = build_owner_sign()
      {:ok, cbor_binary} = OwnerSign.encode_sign_cbor_with_hash(owner_sign, key)
      assert {:ok, _, ""} = CBOR.decode(cbor_binary)
    end
  end
end
