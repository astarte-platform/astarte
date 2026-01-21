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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.SessionTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.FDOSession

  alias Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.FDO.OwnerOnboarding.SessionKey

  import Astarte.Helpers.FDO

  describe "new/4" do
    test "returns required session information", context do
      %{
        realm: realm_name,
        hello_device: hello_device,
        owner_key: owner_key,
        ownership_voucher: ownership_voucher
      } = context

      assert {:ok, _token, session} =
               Session.new(realm_name, hello_device, ownership_voucher, owner_key)

      assert is_binary(session.guid)
      assert session.prove_dv_nonce
      assert session.owner_random
      assert session.xa
      assert {:es256, %COSE.Keys.ECC{}} = session.device_signature
    end
  end

  # DH keys derivation according to FIDO spec section 3.6
  describe "DH shared secret derivation" do
    @tag owner_key: "EC256", kex_name: "ECDH256"
    test "is carried out correctly when device and owner use ECDH256 algorithm", %{
      session: session,
      device_key: device_key,
      device_random: device_random
    } do
      owner_ecdh256_secret = session.secret

      owner_public_key = parse_key_from_xa(session.xa, session.kex_suite_name)

      device_ecdh256_secret =
        compute_device_shared_secret_ecdh(
          device_key,
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
      device_key: device_key,
      device_random: device_random
    } do
      owner_ecdh384_secret = session.secret

      owner_public_key = parse_key_from_xa(session.xa, session.kex_suite_name)

      device_ecdh384_secret =
        compute_device_shared_secret_ecdh(
          device_key,
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
      assert %COSE.Keys.Symmetric{k: binary_key, alg: alg} = session.sevk
      assert is_binary(binary_key)
      assert alg == :aes_256_gcm
    end
  end

  describe "derive_key/2 with P-384 (ECDH384)" do
    setup %{realm: realm_name} do
      {p384_voucher, owner_key_pem} = generate_p384_x5chain_data_and_pem()
      {:ok, p384_owner_key} = COSE.Keys.from_pem(owner_key_pem)

      device_id = p384_voucher.header.guid

      hello_device =
        HelloDevice.generate(
          device_id: device_id,
          kex_name: "ECDH384",
          easig_info: :es384
        )

      p384_device_key = COSE.Keys.ECC.generate(:es384)
      {:ok, _dev_rand, xb} = SessionKey.new("ECDH384", p384_device_key)

      {:ok, _token, session} =
        Session.new(realm_name, hello_device, p384_voucher, p384_owner_key)

      {:ok, session_with_secret} =
        Session.build_session_secret(session, realm_name, p384_owner_key, xb)

      %{session: session_with_secret}
    end

    test "successfully derives keys using SHA-384 logic", %{session: session, realm: realm_name} do
      assert {:ok, derived_session} = Session.derive_key(session, realm_name)
      assert %COSE.Keys.Symmetric{k: key_bytes, alg: :aes_256_gcm} = derived_session.sevk
      assert byte_size(key_bytes) == 32
    end
  end

  defp parse_key_from_xa(xa, kex_name) do
    {x_bytesize, y_bytesize, rand_bytesize} =
      case kex_name do
        "ECDH256" ->
          {32, 32, 16}

        "ECDH384" ->
          {48, 48, 48}
      end

    <<_::binary-size(2), x::binary-size(x_bytesize), _::binary-size(2),
      y::binary-size(y_bytesize), _rest::binary-size(2 + rand_bytesize)>> = xa

    # derived owner public key
    <<4, x::binary, y::binary>>
  end

  defp compute_device_shared_secret_ecdh(device_key, device_random, owner_random, owner_public) do
    point = {:ECPoint, owner_public}
    device_key_record = COSE.Keys.ECC.to_record(device_key)

    shared_secret =
      :public_key.compute_key(point, device_key_record)

    <<shared_secret::binary, device_random::binary, owner_random::binary>>
  end

  defp compute_device_shared_secret_dhkex(xa, device_random, dhkex_group) do
    :crypto.mod_pow(
      :binary.decode_unsigned(xa),
      :binary.decode_unsigned(device_random),
      SessionKey.get_dhkex_p(dhkex_group)
    )
  end
end
