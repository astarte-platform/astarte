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

defmodule Astarte.Helpers.FDO do
  import StreamData

  alias Astarte.Pairing.FDO.OwnershipVoucher.CreateRequest

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

  @sample_private_key """
  -----BEGIN EC PRIVATE KEY-----
  MHcCAQEEIFlbTEE1Ce+RSqhU8FqxsY7eNb9BaBWOTw6qFv7l0DZtoAoGCCqGSM49
  AwEHoUQDQgAEocPEIHIrn08VRO5zkkDztwp72Sw0BSm0mZeLgOKkHLUPdVFFlc0E
  O82b1/S2Cwzwh8MIDDx0CN2b+IBl5bRwOw==
  -----END EC PRIVATE KEY-----
  """

  @sample_rsa_private_key """
  -----BEGIN PRIVATE KEY-----
  MIIBVwIBADANBgkqhkiG9w0BAQEFAASCAUEwggE9AgEAAkEAxw+lVGEbPGxFSGj1
  Czkhitwnz9wblr659Xw2SBqSpjfRHPec+g1k3Iplk+jQ7eeomRGpE5HtmPb0M5bY
  CSUX5QIDAQABAkEArzViPAbMxj42LSnUpXA/yc1FbXs6/VAatawCyyw4b/uZJB7v
  P+r1LJzWvyb9wtSpqBXnHn/URkputzCh+wfGgQIhAP0H1DmVmFN7zmJaPG1UWhp1
  rF3g0B84jvoXLKwKsJPZAiEAyWWtoACg7Y50UMiIa3AlEMDbXXaS7cm73jKkmxrC
  +O0CIQC395Y8m+BZal1+sr7WeorcTAwbYVXQLU3+1RScrVT+2QIhAIoh+SIjDD2j
  VVgLErZN5r5E6LCEIWaC1R4jsg7IHi5JAiEA0GyiiMHskaiASKMVYrRXN6JHryLM
  zSZ13mWNMd/WqR8=
  -----END PRIVATE KEY-----
  """

  @sample_device_guid <<175, 173, 208, 144, 202, 119, 157, 130, 245, 26, 21, 124, 53, 34, 7, 12>>

  @sample_request_rc CreateRequest.changeset(%CreateRequest{}, %{
                       ownership_voucher: @sample_voucher,
                       private_key: @sample_private_key
                     })
                     |> Ecto.Changeset.apply_action!(:insert)

  @sample_request_rsa CreateRequest.changeset(%CreateRequest{}, %{
                        ownership_voucher: @sample_voucher,
                        private_key: @sample_rsa_private_key
                      })
                      |> Ecto.Changeset.apply_action!(:insert)

  def sample_voucher, do: @sample_voucher
  def sample_private_key, do: @sample_private_key
  def sample_extracted_private_key, do: @sample_request_rc.extracted_private_key
  def sample_extracted_rsa_private_key, do: @sample_request_rsa.extracted_private_key
  def sample_rsa_private_key, do: @sample_rsa_private_key
  def sample_device_guid, do: @sample_device_guid

  def nonce, do: binary(length: 16)

  def hello_ack(nonce) do
    CBOR.encode([%CBOR.Tag{tag: :bytes, value: nonce}])
  end
end
