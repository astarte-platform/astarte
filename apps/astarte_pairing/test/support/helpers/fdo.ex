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
  MIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCphTib16sbghc+
  tVaqAl5WcebrBe4vxGH0cDFcVmXlIQjfh020ePYvqG+6PVitIRQ8sGgx5t+yT06l
  CG2z0YVq8mpVXFLC7YLCjBVlms6QFcBshkxVRU2jj8vuhP/SIf0Ze9kbeN4HKDji
  csoAXy8bUXVTQRgd7yCCULL35LdXHIQ2iwDxuBpVgjczk4swSqa2YMy8BIFLbmSZ
  ENAsS2KeP0f4OO9HFzOF1eT0yUTdOmNrBKzvsk+AeKNt0MXf8zbAulIrRZIgUyZe
  Creq75XbXapRrZitfbZyX6ZvWQykQLDCyOFAv4fWMd/8JHuqAZsqGACDEm0cU8eA
  Z4Z+L4lRAgMBAAECggEADOh+XqzgdEVxUa7AkkzV3s0+Nn01cuEITchRPzpmTePj
  EhTydMs/1nHZTXF9vskltQKrHHRRFPnMVO1nCmnqN9ziU0JRcahg7EF7IPPVxiDx
  4xGi3wdaRG8e/zg/ZpfR9vki7LWaan8Z6HGx3K9iyI4Tr1WQlDmbhxtv//JO3Pdz
  hqEdrGIEU2lJ7t+IGOLamSL1Q+fPSbENBdnFBdu4SiSJpBJno7YRZVp7weW41jYx
  svPBnLAibUDyGXEbHqSEs/vy3IEYxjH+Ioyambqh8YR19FzBy6ld1kipt6ddE+Zu
  O/ApnzrAfAxbpEMfqLcoYuF1GawjOF72zck2QM0GBQKBgQDRa2WB/mQkQlVIpMuH
  QAgqLuaYv6dlzEkl4NOrv3kyNYLWDWqdJzF13a1ICuvgQX71jNMI/NDI1uxrEbK2
  /5sC00cHACPs2zlMmNvvstv4TQVVl9ioaEn4Y2ONsv+nSD/p0fv9lJZABoCy4yXS
  BCQudWaTvqFNTCJuvPxEcmIi1wKBgQDPOet2BBWhbSgtdZYwNJNcQzQtGgLCd4TL
  uqS4yMeLpKmT9zfOhOdGOlVSssMStDwGEKqBrNp9/Wt9giL8/F9ZkoyKbmvGlRI9
  z17XPTdJAd3+DnS+l1ulCt9M9Ysrf1s17uHGCSFgxSHuOW2KlgF7lKOb+RjK53S+
  sMeLD6/YFwKBgA4/m2Fz2IZrCPhvVfW20pdkJ4ZfC9muQ4/TMzOtTGaxI1zC/u0A
  XKojUgXj0FaqviOg2D71TJNNpDpIsvsmevp/O4braIZWCBkBEX3GkpbbTrCbKz+S
  EO5YfM6ITkKodMjI47dGI87pYlpJgCpA4+FRVZBZ2Qm0U2drblKN4cVzAoGBAMDA
  /2QnKHefMWAXoDv2q5uGZ2IMb8Szp7JZSh8Xo4UhBRu9OQvAU9/fIr5pyUn8nFiH
  6BH21sWalAGKq0Dm/0oyJsgdLeLphq431eAf8OzX78YBbFZcM8Kw+kR7oZg0PoNM
  UHYEyCdbNtSAVoQyQ+7Ps9/BNG6IHO/DP9j6HnbBAoGAcErnhRKOWZeX2X5gFkjw
  CQ1QSdjNLsJEOXcm1SPCFrDF9bLtuyIynkPeUFB2ki82gBaH4qx/5eEG//6KfFwG
  9nMKvSEg2D0Iy6l9xhqfrE0e8fPdsLSZVPANCr90QNEahvWxpoeR+uZouWI49VxK
  qbAKYV8ryPBy2s+b+5IstCI=
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
