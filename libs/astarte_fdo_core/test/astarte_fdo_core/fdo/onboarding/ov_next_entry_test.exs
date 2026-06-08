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

defmodule Astarte.FDO.Core.Onboarding.OvNextEntryTest do
  use ExUnit.Case, async: true

  alias Astarte.FDO.Core.OwnershipVoucher
  alias Astarte.FDO.Core.OwnershipVoucher.Core

  @sample_voucher """
  -----BEGIN OWNERSHIP VOUCHER-----
  hRhlWM+GGGVQr63QkMp3nYL1GhV8NSIHDIGEggNDGR+SggJFRH8AAAGCBEMZH5KC
  DEEBa3Rlc3QtZGV2aWNlgwoBWFswWTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAAR+
  ZAJTHLueZHU5DX1qdH6ZvbvmW69aO2RK+uJ20YSmeJZTp1TiV3jpdBhyEOr1pY1O
  jPvl3vS/j/gbrSCwr+rfgjgqWDBZh6iPbdAa5zursMvPQeFRIFck3btlLPsXozLj
  E0eV+ktxM0RdDTSr93qKaHcxyVOCBlgwwbWxktdFSJYycNKe/nOUEM/38hWmgZqT
  KTuhUp5bj+njyqipW+XieEZWi/hI4aLQglkBPjCCATowgeGgAwIBAgIJANsx49Cs
  aXDMMAoGCCqGSM49BAMDMDAxDzANBgNVBAMMBkRldmljZTEQMA4GA1UECgwHRXhh
  bXBsZTELMAkGA1UEBhMCVVMwHhcNMjUxMDI3MTQyMTQxWhcNMzUxMDI1MTQyMTQx
  WjAWMRQwEgYDVQQDDAt0ZXN0LWRldmljZTBZMBMGByqGSM49AgEGCCqGSM49AwEH
  A0IABP2JVosdcxoaEhwUM0Cs3o7RpyTVVWA3m7/fa4NpjSD2l4LFAAnDmQeQmGEA
  Zb7bDegDV25BJGJZEllUykjpDCswCgYIKoZIzj0EAwMDSAAwRQIgCzLXLWA+HyzK
  SbOjsey72cVUyIseO5ZccBqk3riDaMwCIQCn6GGwvDYrqFCv7E/S4CavqIjh2qTn
  Zrw5SPrFFlaQNFkBVzCCAVMwgfqgAwIBAgIIONKn09qIvrMwCgYIKoZIzj0EAwIw
  MDEPMA0GA1UEAwwGRGV2aWNlMRAwDgYDVQQKDAdFeGFtcGxlMQswCQYDVQQGEwJV
  UzAeFw0yNTEwMjcxMjAwMTJaFw0yNjEwMjcxMjAwMTJaMDAxDzANBgNVBAMMBkRl
  dmljZTEQMA4GA1UECgwHRXhhbXBsZTELMAkGA1UEBhMCVVMwWTATBgcqhkjOPQIB
  BggqhkjOPQMBBwNCAAS2VYoG7RvZJ3viS2iIJHJ3Kc6RBxrLvU4cXMwzf3BVmbMD
  0Fm7RCul90MY0HA70mo2uliQl+hBIPt6CZL88HnlMAoGCCqGSM49BAMCA0gAMEUC
  IQD8o8cHYlu173xtkO+iYWDz1YtlHX5qgM+5eI+bAxiWDQIgeAI42brmHjg8k8uL
  hCBiOubCszNsE8nt95lmrbx4SPeB0oRDoQEmoFjMhII4KlgwjcflehRF07wE+oSS
  rvbtBDn2SfN2NJY5BoIR3cJwaW2BHUILDIp6dK+MFEU8gMgngjgqWDAlmi74Lcun
  Drl3FFJMbuEkFbijwOnEwLkK5YRtjZHZhqCjiNAj7dJZdbOTzaauvnD2gwoBWFsw
  WTATBgcqhkjOPQIBBggqhkjOPQMBBwNCAARL5OQDtW0lC/1hDvnKXlu1cpH9yyjJ
  8vNhZRODFWIYx8mS+qXhbfOu1FpU9T0jTpM4cULYzDL71LcDtRa/8Ra2WEDgl/oT
  yVhaI7XTPziNidQB/6h7rAsYKGjb1odrsLdmeFObSIdVHgG3GLGc/mq/3AMhy5tl
  rPbEwDSoPhfFnX0W
  -----END OWNERSHIP VOUCHER-----
  """

  describe "get_ov_entry/2" do
    setup do
      {:ok, voucher} = @sample_voucher |> OwnershipVoucher.Core.decode_ownership_voucher()
      {:ok, decoded_voucher} = OwnershipVoucher.decode(voucher)

      {:ok,
       %{
         voucher: decoded_voucher,
         entries: decoded_voucher.entries,
         count: length(decoded_voucher.entries)
       }}
    end

    test "returns {:ok, cbor_binary} when entry_num is valid", %{
      voucher: voucher,
      entries: ov_entries
    } do
      entry_num = 0
      expected_entry = Enum.at(ov_entries, entry_num)

      assert {:ok, encoded} = Core.get_ov_entry(voucher, entry_num)

      assert {:ok, [^entry_num, ^expected_entry], ""} = CBOR.decode(encoded)
    end

    test "returns {:ok, cbor_binary} when entry_num is valid and is the last entry", %{
      voucher: voucher,
      entries: ov_entries,
      count: count
    } do
      entry_num = count - 1
      expected_entry = Enum.at(ov_entries, entry_num)

      assert {:ok, encoded} = Core.get_ov_entry(voucher, entry_num)

      assert {:ok, [^entry_num, ^expected_entry], ""} = CBOR.decode(encoded)
    end

    test "returns error for negative entry_num", %{voucher: voucher} do
      assert {:error, :invalid_message} =
               Core.get_ov_entry(voucher, -1)
    end

    test "returns error when entry_num is over the max number ov entries", %{
      voucher: voucher,
      count: invalid_index
    } do
      assert {:error, :invalid_message} =
               Core.get_ov_entry(voucher, invalid_index)
    end
  end
end
