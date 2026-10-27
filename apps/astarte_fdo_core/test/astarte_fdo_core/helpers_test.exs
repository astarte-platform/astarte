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

defmodule Astarte.FDO.Core.HelpersTest do
  use ExUnit.Case, async: true
  use Mimic

  alias Astarte.FDO.Core.Helpers
  alias Astarte.FDO.Core.OwnershipVoucher
  alias COSE.Keys.ECC

  # A voucher whose cert_chain is nil → device_public_key returns {:ok, nil}
  @voucher_no_cert %OwnershipVoucher{cert_chain: nil}
  # A voucher whose cert_chain is [] → device_public_key returns :error
  @voucher_bad_cert %OwnershipVoucher{cert_chain: []}

  describe "validate_signature_info/2 — EPID types (no device key needed)" do
    test "eipd10 with nil pubkey returns ok" do
      sig = {:eipd10, :crypto.strong_rand_bytes(16)}
      assert {:ok, ^sig} = Helpers.validate_signature_info(sig, @voucher_no_cert)
    end

    test "eipd11 with nil pubkey returns ok" do
      sig = {:eipd11, :crypto.strong_rand_bytes(16)}
      assert {:ok, ^sig} = Helpers.validate_signature_info(sig, @voucher_no_cert)
    end

    test "non-epid sig_info with nil pubkey returns error" do
      assert :error = Helpers.validate_signature_info(:es256, @voucher_no_cert)
    end
  end

  describe "validate_signature_info/2 — ES256" do
    test "valid P-256 ECPoint returns {:ok, {:es256, key}}" do
      x = :crypto.strong_rand_bytes(32)
      y = :crypto.strong_rand_bytes(32)
      ec_point = {:ECPoint, <<4, x::binary, y::binary>>}

      stub(OwnershipVoucher, :device_public_key, fn _ -> {:ok, ec_point} end)

      assert {:ok, {:es256, %ECC{alg: :es256, crv: :p256, x: ^x, y: ^y}}} =
               Helpers.validate_signature_info(:es256, @voucher_no_cert)
    end

    test "malformed ECPoint returns error" do
      stub(OwnershipVoucher, :device_public_key, fn _ -> {:ok, {:ECPoint, <<0, 1, 2>>}} end)

      assert :error = Helpers.validate_signature_info(:es256, @voucher_no_cert)
    end
  end

  describe "validate_signature_info/2 — ES384" do
    test "valid P-384 ECPoint returns {:ok, {:es384, key}}" do
      x = :crypto.strong_rand_bytes(48)
      y = :crypto.strong_rand_bytes(48)
      ec_point = {:ECPoint, <<4, x::binary, y::binary>>}

      stub(OwnershipVoucher, :device_public_key, fn _ -> {:ok, ec_point} end)

      assert {:ok, {:es384, %ECC{alg: :es384, crv: :p384, x: ^x, y: ^y}}} =
               Helpers.validate_signature_info(:es384, @voucher_no_cert)
    end

    test "malformed ECPoint returns error" do
      stub(OwnershipVoucher, :device_public_key, fn _ -> {:ok, {:ECPoint, <<0>>}} end)

      assert :error = Helpers.validate_signature_info(:es384, @voucher_no_cert)
    end
  end

  describe "validate_signature_info/2 — unrecognised sig_info" do
    test "rs256 with a pubkey returns error" do
      stub(OwnershipVoucher, :device_public_key, fn _ ->
        {:ok, {:ECPoint, :crypto.strong_rand_bytes(32)}}
      end)

      assert :error = Helpers.validate_signature_info(:rs256, @voucher_no_cert)
    end
  end

  describe "validate_signature_info/2 — device_public_key error propagation" do
    test "propagates :error from device_public_key" do
      assert :error = Helpers.validate_signature_info(:es256, @voucher_bad_cert)
    end
  end
end
