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

  alias Astarte.DataAccess.FDO.OwnershipVoucher, as: DBOwnershipVoucher
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias Astarte.Pairing.FDO.OwnershipVoucher.CreateRequest
  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo
  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RendezvousDirective
  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo.RendezvousInstr
  alias Astarte.Pairing.FDO.Types.PublicKey
  alias Astarte.Pairing.FDO.Types.Hash
  alias COSE.Keys.ECC
  alias COSE.Messages.Sign1

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

  @sample_rv_info %RendezvousInfo{
    directives: [
      %RendezvousDirective{
        instructions: [
          %RendezvousInstr{
            rv_value: "ufdo.astarte.localhost",
            rv_variable: :dns
          },
          %RendezvousInstr{
            rv_value: <<1>>,
            rv_variable: :protocol
          },
          %RendezvousInstr{
            rv_value: <<24, 80>>,
            rv_variable: :dev_port
          },
          %RendezvousInstr{
            rv_value: <<25, 31, 105>>,
            rv_variable: :owner_port
          },
          %RendezvousInstr{
            rv_value: "\n",
            rv_variable: :delaysec
          }
        ]
      }
    ]
  }

  def sample_voucher, do: @sample_voucher
  def sample_cbor_voucher, do: @sample_request_rc.cbor_ownership_voucher
  def sample_private_key, do: @sample_private_key
  def sample_extracted_private_key, do: @sample_request_rc.extracted_private_key
  def sample_extracted_rsa_private_key, do: @sample_request_rsa.extracted_private_key
  def sample_rsa_private_key, do: @sample_rsa_private_key
  def sample_device_guid, do: @sample_device_guid
  def sample_rv_info, do: @sample_rv_info

  def sample_ownership_voucher do
    {:ok, voucher} = OwnershipVoucher.decode_cbor(sample_cbor_voucher())
    voucher
  end

  def nonce, do: binary(length: 16)

  def hello_ack(nonce) do
    CBOR.encode([%CBOR.Tag{tag: :bytes, value: nonce}])
  end

  def insert_voucher(realm_name, private_key, cbor_voucher, device_id) do
    %DBOwnershipVoucher{
      voucher_data: cbor_voucher,
      private_key: private_key,
      device_id: device_id
    }
    |> Repo.insert(prefix: Realm.keyspace_name(realm_name))
  end

  def generate_p384_x5chain_data_and_pem() do
    generate_voucher_data_and_pem(curve: :p384, encoding: :x5chain)
  end

  def generate_p384_x509_data_and_pem() do
    generate_voucher_data_and_pem(curve: :p384, encoding: :x509)
  end

  def generate_p256_x5chain_data_and_pem() do
    generate_voucher_data_and_pem(curve: :p256, encoding: :x5chain)
  end

  def generate_p256_x509_data_and_pem() do
    generate_voucher_data_and_pem()
  end

  # Generic generator for all supported curves and encodings
  # Options:
  #   :curve -> :p256 or :p384 (default :p256)
  #   :encoding -> :x509 or :x5chain (default :x509)
  #   :device_key -> an EC256 or EC384 device key used for attestation inside the voucher;
  #                  if empty, a new key will be generated on the fly according to the curve type
  def generate_voucher_data_and_pem(opts \\ []) do
    curve = Keyword.get(opts, :curve, :p256)
    encoding = Keyword.get(opts, :encoding, :x509)

    # Curve parameters
    {oid, hash_alg, sig_alg, _fdo_alg_id, pub_key_type} = get_curve_params(curve)

    cose_alg = if curve == :p256, do: :es256, else: :es384

    cose_key = Keyword.get_lazy(opts, :device_key, fn -> ECC.generate(cose_alg) end)

    %ECC{alg: ^cose_alg} = cose_key

    device_pub_key_point = <<4, cose_key.x::binary, cose_key.y::binary>>

    device_priv_key = {
      :ECPrivateKey,
      1,
      cose_key.d,
      {:namedCurve, oid},
      device_pub_key_point,
      :asn1_NOVALUE
    }

    # Self signed cert
    cert_der = generate_self_signed_cert(device_pub_key_point, device_priv_key, oid, sig_alg)

    pem =
      :public_key.pem_entry_encode(:ECPrivateKey, device_priv_key)
      |> List.wrap()
      |> :public_key.pem_encode()

    pub_key_body =
      case encoding do
        :x5chain -> [cert_der]
        :x509 -> cert_der
      end

    # Entry Payload (COSE Key)
    entry_payload_bin = create_cose_key_entry_payload(cose_key, curve)

    guid_raw = UUID.uuid4(:raw)

    chain_data_to_hash =
      case pub_key_body do
        list when is_list(list) -> Enum.join(list)
        bin -> bin
      end

    cert_chain_hash_struct = Hash.new(hash_alg, chain_data_to_hash)

    rv_info = %RendezvousInfo{
      directives: [
        %RendezvousDirective{
          instructions: [
            %RendezvousInstr{rv_variable: :dev_port, rv_value: <<25, 31, 146>>},
            %RendezvousInstr{rv_variable: :ip_address, rv_value: <<68, 127, 0, 0, 1>>},
            %RendezvousInstr{rv_variable: :owner_port, rv_value: <<25, 31, 146>>},
            %RendezvousInstr{rv_variable: :protocol, rv_value: <<1>>}
          ]
        }
      ]
    }

    header_struct = %OwnershipVoucher.Header{
      guid: guid_raw,
      device_info: "#{curve}-device",
      public_key: %PublicKey{type: pub_key_type, encoding: encoding, body: pub_key_body},
      rendezvous_info: rv_info,
      cert_chain_hash: cert_chain_hash_struct,
      protocol_version: 101
    }

    {hmac_len, hmac_type} =
      case hash_alg do
        :sha256 -> {32, :hmac_sha256}
        :sha384 -> {48, :hmac_sha384}
      end

    hmac_bytes = :crypto.strong_rand_bytes(hmac_len)
    hmac_struct = %Hash{type: hmac_type, hash: hmac_bytes}

    protected_header = %{alg: cose_alg}
    unprotected_header_map = %{}

    sign1_msg = Sign1.build(entry_payload_bin, protected_header, unprotected_header_map)

    entry_tag = Sign1.sign_encode(sign1_msg, cose_key)

    voucher = %OwnershipVoucher{
      header: header_struct,
      hmac: hmac_struct,
      entries: [entry_tag],
      protocol_version: 101,
      cert_chain: [cert_der]
    }

    {voucher, pem}
  end

  defp get_curve_params(:p256) do
    # OID, HashAlg, SigAlg, COSE Alg ID (:es256 = -7), PublicKeyType (:secp256r1 = 10)
    {{1, 2, 840, 10045, 3, 1, 7}, :sha256, {:sha256, :ecdsa}, -7, :secp256r1}
  end

  defp get_curve_params(:p384) do
    # OID, HashAlg, SigAlg, COSE Alg ID (:es384 = -35), PublicKeyType (:secp384r1 = 11)
    {{1, 3, 132, 0, 34}, :sha384, {:sha384, :ecdsa}, -35, :secp384r1}
  end

  defp generate_self_signed_cert(pub_key_point, priv_key, oid, sig_alg) do
    sig_oid =
      case sig_alg do
        {:sha256, :ecdsa} -> {1, 2, 840, 10045, 4, 3, 2}
        {:sha384, :ecdsa} -> {1, 2, 840, 10045, 4, 3, 3}
      end

    validity = {:Validity, {:utcTime, ~c"240101000000Z"}, {:utcTime, ~c"340101000000Z"}}

    subject =
      {:rdnSequence, [[{:AttributeTypeAndValue, {2, 5, 4, 3}, {:utf8String, "Test Device"}}]]}

    spki =
      {:OTPSubjectPublicKeyInfo,
       {:PublicKeyAlgorithm, {1, 2, 840, 10045, 2, 1}, {:namedCurve, oid}},
       {:ECPoint, pub_key_point}}

    tbs_cert =
      {
        :OTPTBSCertificate,
        :v3,
        123_456,
        {:SignatureAlgorithm, sig_oid, :asn1_NOVALUE},
        subject,
        validity,
        subject,
        spki,
        :asn1_NOVALUE,
        :asn1_NOVALUE,
        :asn1_NOVALUE
      }

    :public_key.pkix_sign(tbs_cert, priv_key)
  end

  defp create_cose_key_entry_payload(%ECC{x: x, y: y}, curve) do
    {cose_crv, cose_alg} =
      if curve == :p256, do: {1, -7}, else: {2, -35}

    cose_key_map = %{
      1 => 2,
      -1 => cose_crv,
      3 => cose_alg,
      -2 => x,
      -3 => y
    }

    type_int = if curve == :p256, do: 10, else: 11
    enc_int = 3

    key_bytes = CBOR.encode(cose_key_map)

    fdo_public_key = [
      type_int,
      enc_int,
      %CBOR.Tag{tag: :bytes, value: key_bytes}
    ]

    entry_list = [<<>>, <<>>, <<>>, fdo_public_key]

    CBOR.encode(entry_list)
  end
end
