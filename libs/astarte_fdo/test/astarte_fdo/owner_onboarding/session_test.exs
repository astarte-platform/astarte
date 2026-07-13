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

defmodule Astarte.FDO.OwnerOnboarding.SessionTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.FDOSession
  use Mimic

  alias Astarte.DataAccess.FDO.Queries
  alias Astarte.FDO.Core.OwnerOnboarding.HelloDevice
  alias Astarte.FDO.Core.OwnerOnboarding.OwnerServiceInfo
  alias Astarte.FDO.Core.OwnerOnboarding.SessionKey
  alias Astarte.FDO.OwnerOnboarding.Session
  alias Astarte.RPC.RealmManagement
  alias COSE.Keys
  alias COSE.Keys.ECC
  alias COSE.Keys.Symmetric

  import Astarte.FDO.Helpers

  describe "new/4" do
    test "returns required session information", context do
      %{
        realm: realm_name,
        hello_device: hello_device,
        ownership_voucher: ownership_voucher
      } = context

      assert {:ok, _token, session} =
               Session.new(
                 realm_name,
                 hello_device,
                 ownership_voucher
               )

      assert is_binary(session.guid)
      assert session.prove_dv_nonce
      assert session.owner_random
      assert session.xa
      assert {:es256, %ECC{}} = session.device_signature
    end

    test "cleans up previously registered devices", context do
      %{
        realm: realm_name,
        hello_device: hello_device,
        device_id: device_id,
        encoded_device_id: encoded_device_id,
        ownership_voucher: ownership_voucher
      } = context

      create_session_with_device_id(realm_name, hello_device, ownership_voucher, device_id)

      RealmManagement
      |> expect(:delete_device, fn ^realm_name, ^encoded_device_id -> :ok end)

      assert {:ok, _, _} = Session.new(realm_name, hello_device, ownership_voucher)
    end

    test "cleans up previous device session", context do
      %{
        realm: realm_name,
        hello_device: hello_device,
        ownership_voucher: ownership_voucher
      } = context

      guid = hello_device.guid

      assert {:ok, token_1, _session} =
               Session.new(
                 realm_name,
                 hello_device,
                 ownership_voucher
               )

      Queries
      |> expect(:delete_session, fn ^realm_name, ^guid -> :ok end)

      assert {:ok, token_2, _session} =
               Session.new(
                 realm_name,
                 hello_device,
                 ownership_voucher
               )

      assert token_1 != token_2
    end
  end

  # DH keys derivation according to FIDO spec section 3.6
  describe "DH shared secret derivation" do
    @tag owner_key: "EC256", kex_name: "ECDH256"
    test "is carried out correctly when device and owner use ECDH256 algorithm", %{
      session: session,
      device_random: device_random
    } do
      owner_ecdh256_secret = session.secret

      owner_public_key = parse_key_from_xa(session.xa)

      device_ecdh256_secret =
        compute_device_shared_secret_ecdh(
          session.kex_suite_name,
          device_random,
          session.owner_random,
          owner_public_key
        )

      assert is_binary(owner_ecdh256_secret)
      assert owner_ecdh256_secret == device_ecdh256_secret
      # secret size: 32 bytes (EC256 public key) + 2 * 16 bytes (device random + owner random)
      assert byte_size(owner_ecdh256_secret) == 64
    end

    @tag owner_key: "EC384", kex_name: "ECDH384"
    test "is carried out correctly when device and owner use ECDH384 algorithm", %{
      session: session,
      device_random: device_random
    } do
      owner_ecdh384_secret = session.secret

      owner_public_key = parse_key_from_xa(session.xa)

      device_ecdh384_secret =
        compute_device_shared_secret_ecdh(
          session.kex_suite_name,
          device_random,
          session.owner_random,
          owner_public_key
        )

      assert is_binary(owner_ecdh384_secret)
      assert owner_ecdh384_secret == device_ecdh384_secret
      # secret size: 48 bytes (EC384 public key) + 2 * 48 bytes (device random + owner random)
      assert byte_size(owner_ecdh384_secret) == 144
    end

    @tag owner_key: "RSA2048", kex_name: "DHKEXid14"
    test "is carried out correctly when device and owner use DHKEXid14 algorithm", %{
      session: session,
      device_random: device_random
    } do
      owner_dhkex14_secret = session.secret

      dhkex_group = 14

      device_dhkex14_secret =
        compute_device_shared_secret_dhkex(session.xa, device_random, dhkex_group)

      assert is_binary(owner_dhkex14_secret)
      assert owner_dhkex14_secret == device_dhkex14_secret
      # secret size: 256 byes (RSA-2048 key size)
      assert byte_size(owner_dhkex14_secret) == 256
    end

    @tag owner_key: "RSA3072", kex_name: "DHKEXid15"
    test "is carried out correctly when device and owner use DHKEXid15 algorithm", %{
      session: session,
      device_random: device_random
    } do
      owner_dhkex15_secret = session.secret

      dhkex_group = 15

      device_dhkex15_secret =
        compute_device_shared_secret_dhkex(session.xa, device_random, dhkex_group)

      assert is_binary(owner_dhkex15_secret)
      assert owner_dhkex15_secret == device_dhkex15_secret
      # secret size: 384 byes (RSA-3072 key size)
      assert byte_size(owner_dhkex15_secret) == 384
    end

    @tag owner_key: "RSA2048", kex_name: "ASYMKEX2048"
    test "is carried out correctly when device and owner use ASYMKEX2048 algorithm", %{
      session: session,
      device_random: device_random
    } do
      owner_asymkex2048_secret = session.secret

      assert is_binary(owner_asymkex2048_secret)
      # for ASYMKEX, device_secret == device_random
      assert owner_asymkex2048_secret == device_random
      # secret size: 32 bytes (device random)
      assert byte_size(owner_asymkex2048_secret) == 32
    end

    @tag owner_key: "RSA3072", kex_name: "ASYMKEX3072"
    test "is carried out correctly when device and owner use ASYMKEX3072 algorithm", %{
      session: session,
      device_random: device_random
    } do
      owner_asymkex3072_secret = session.secret

      assert is_binary(owner_asymkex3072_secret)
      # for ASYMKEX, device_secret == device_random
      assert owner_asymkex3072_secret == device_random
      # secret size: 96 bytes (device random)
      assert byte_size(owner_asymkex3072_secret) == 96
    end
  end

  describe "derive_key/2" do
    setup context do
      %{
        realm: realm_name,
        xb: xb,
        session: session,
        owner_key: owner_key
      } = context

      {:ok, session} = Session.build_session_secret(session, realm_name, owner_key, xb)

      %{session: session}
    end

    test "returns the derived key", context do
      %{
        realm: realm_name,
        session: session
      } = context

      assert {:ok, session} = Session.derive_key(session, realm_name)
      assert %Symmetric{k: binary_key, alg: alg} = session.sevk
      assert is_binary(binary_key)
      assert alg == :aes_256_gcm
    end
  end

  describe "derive_key/2 with P-384 (ECDH384)" do
    setup %{realm: realm_name} do
      {p384_voucher, owner_key_pem} = generate_p384_x5chain_data_and_pem()
      {:ok, p384_owner_key} = Keys.from_pem(owner_key_pem)

      device_id = p384_voucher.header.guid

      hello_device =
        HelloDevice.generate(
          device_id: device_id,
          kex_name: "ECDH384",
          easig_info: :es384
        )

      {:ok, _dev_rand, xb} = SessionKey.new("ECDH384")

      {:ok, _token, session} =
        Session.new(realm_name, hello_device, p384_voucher)

      {:ok, session_with_secret} =
        Session.build_session_secret(session, realm_name, p384_owner_key, xb)

      %{session: session_with_secret}
    end

    test "successfully derives keys using SHA-384 logic", %{session: session, realm: realm_name} do
      assert {:ok, derived_session} = Session.derive_key(session, realm_name)
      assert %Symmetric{k: key_bytes, alg: :aes_256_gcm} = derived_session.sevk
      assert byte_size(key_bytes) == 32
    end
  end

  describe "next_owner_service_info_chunk/2" do
    setup %{realm: realm_name} do
      {p384_voucher, owner_key_pem} = generate_p384_x5chain_data_and_pem()
      {:ok, p384_owner_key} = Keys.from_pem(owner_key_pem)

      device_id = p384_voucher.header.guid

      hello_device =
        HelloDevice.generate(
          device_id: device_id,
          kex_name: "ECDH384",
          easig_info: :es384
        )

      {:ok, _dev_rand, xb} = SessionKey.new("ECDH384")

      {:ok, _token, session} =
        Session.new(realm_name, hello_device, p384_voucher)

      {:ok, session} =
        Session.build_session_secret(session, realm_name, p384_owner_key, xb)

      chunks = [<<1>>, <<2>>]
      {:ok, session} = Session.add_owner_service_info(session, realm_name, chunks)

      %{session: session, chunks: chunks}
    end

    test "returns the first chunk the first time", context do
      %{realm_name: realm_name, session: session, chunks: chunks} = context

      first_chunk = Enum.at(chunks, 0)

      assert {:ok, new_session, ^first_chunk} =
               Session.next_owner_service_info_chunk(session, realm_name)

      assert new_session.last_chunk_sent == 0
    end

    test "returns later chunks with subsequent calls", context do
      %{realm_name: realm_name, session: session, chunks: chunks} = context
      second_chunk = Enum.at(chunks, 1)

      {:ok, session, _first_chunk} = Session.next_owner_service_info_chunk(session, realm_name)

      assert {:ok, new_session, ^second_chunk} =
               Session.next_owner_service_info_chunk(session, realm_name)

      assert new_session.last_chunk_sent == 1
    end

    test "returns done after it's sent all messages", context do
      %{realm_name: realm_name, session: session, chunks: chunks} = context
      done_chunk = OwnerServiceInfo.done()
      chunks_len = Enum.count(chunks)

      # zero base index
      last_chunk = chunks_len - 1

      # consume the chunks
      session =
        for _ <- 1..chunks_len, reduce: session do
          session ->
            {:ok, session, _next_chunk} =
              Session.next_owner_service_info_chunk(session, realm_name)

            session
        end

      assert {:ok, session_1, ^done_chunk} =
               Session.next_owner_service_info_chunk(session, realm_name)

      assert {:ok, session_2, ^done_chunk} =
               Session.next_owner_service_info_chunk(session_1, realm_name)

      assert session_1.last_chunk_sent == last_chunk
      assert session_2.last_chunk_sent == last_chunk
    end
  end

  defp parse_key_from_xa(xa) do
    <<blen_x::integer-unsigned-size(16), rest::binary>> = xa
    <<x::binary-size(blen_x), rest::binary>> = rest
    <<blen_y::integer-unsigned-size(16), rest::binary>> = rest
    <<y::binary-size(blen_y), _rest::binary>> = rest

    <<4, x::binary, y::binary>>
  end

  defp compute_device_shared_secret_ecdh(kex_suite, device_random, owner_random, owner_public) do
    curve =
      case kex_suite do
        "ECDH256" -> :secp256r1
        "ECDH384" -> :secp384r1
      end

    shared_secret =
      :crypto.compute_key(:ecdh, owner_public, device_random, curve)

    <<shared_secret::binary, device_random::binary, owner_random::binary>>
  end

  defp compute_device_shared_secret_dhkex(xa, device_random, dhkex_group) do
    key_size = if dhkex_group == 14, do: 256, else: 384

    result =
      :crypto.mod_pow(
        :binary.decode_unsigned(xa),
        :binary.decode_unsigned(device_random),
        SessionKey.get_dhkex_p(dhkex_group)
      )

    :binary.copy(<<0>>, key_size - byte_size(result)) <> result
  end
end
