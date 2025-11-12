#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

  import Astarte.Helpers.Device

  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias Astarte.Pairing.Queries
  use Mimic

  @realm_name "test"

  @ownership_voucher """
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
  @invalid_ownership_voucher """
    -----BEGIN OWNERSHIP VOUCHER-----
    some invalid voucher
    -----END OWNERSHIP VOUCHER-----
  """
  @private_key """
  -----BEGIN EC PRIVATE KEY-----
  MHcCAQEEIFlbTEE1Ce+RSqhU8FqxsY7eNb9BaBWOTw6qFv7l0DZtoAoGCCqGSM49
  AwEHoUQDQgAEocPEIHIrn08VRO5zkkDztwp72Sw0BSm0mZeLgOKkHLUPdVFFlc0E
  O82b1/S2Cwzwh8MIDDx0CN2b+IBl5bRwOw==
  -----END EC PRIVATE KEY-----
  """

  @invalid_private_key """
    AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
  """

  describe "handle ownership voucher," do
    test "save voucher data ", ctx do
      %{
        realm_name: realm_name
      } = ctx

      assert :ok = OwnershipVoucher.save_voucher(realm_name, @ownership_voucher, @private_key)
    end

    # test "reject with malformed private key", ctx do
    #   %{
    #     realm_name: realm_name
    #   } = ctx

    #   assert {:error, :invalid_private_key} =
    #            OwnershipVoucher.save_voucher(realm_name, @ownership_voucher, @invalid_private_key)
    # end

    test "reject with malformed voucher", ctx do
      %{
        realm_name: realm_name
      } = ctx

      Mimic.reject(&Queries.create_ownership_voucher/5)

      assert {:error, _} =
               OwnershipVoucher.save_voucher(realm_name, @invalid_ownership_voucher, @private_key)
    end
  end
end
