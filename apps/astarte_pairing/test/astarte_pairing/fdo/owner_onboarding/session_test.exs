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

  alias Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.FDO.OwnerOnboarding.SessionKey

  import Astarte.Helpers.FDO

  setup_all do
    hello_device = HelloDevice.generate()
    ownership_voucher = sample_ownership_voucher()
    owner_key = sample_extracted_private_key()
    device_key = COSE.Keys.ECC.generate(:es256)
    {:ok, device_random, xb} = SessionKey.new(hello_device.kex_name, device_key)

    %{
      hello_device: hello_device,
      ownership_voucher: ownership_voucher,
      owner_key: owner_key,
      device_key: device_key,
      device_random: device_random,
      xb: xb
    }
  end

  setup context do
    %{
      astarte_instance_id: astarte_instance_id,
      hello_device: hello_device,
      ownership_voucher: ownership_voucher,
      realm: realm_name,
      owner_key: owner_key
    } = context

    {:ok, session} =
      Session.new(realm_name, hello_device, ownership_voucher, owner_key)

    on_exit(fn ->
      setup_database_access(astarte_instance_id)
      delete_session(realm_name, session.key)
    end)

    %{session: session}
  end

  describe "new/4" do
    test "returns required session information", context do
      %{
        realm: realm_name,
        hello_device: hello_device,
        owner_key: owner_key,
        ownership_voucher: ownership_voucher
      } = context

      assert {:ok, session} =
               Session.new(realm_name, hello_device, ownership_voucher, owner_key)

      assert is_binary(session.key)
      assert session.prove_dv_nonce
      assert session.owner_random
      assert session.xa
      assert {:es256, %COSE.Keys.ECC{}} = session.device_signature
    end
  end

  describe "build_session_secret/4" do
    test "returns the shared secret", context do
      %{
        realm: realm_name,
        xb: xb,
        session: session,
        owner_key: owner_key
      } = context

      assert {:ok, new_session} = Session.build_session_secret(session, realm_name, owner_key, xb)
      assert is_binary(new_session.secret)
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

      {:ok, session} =
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
end
