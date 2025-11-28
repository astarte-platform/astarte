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

  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.FDO.OwnerOnboarding.SessionKey

  import Astarte.Helpers.FDO

  setup_all do
    key_exchange_format = "ECDH256"
    cipher_suite_name = "A256GCM"
    device_id = Astarte.Core.Device.random_device_id()
    device_key = COSE.Keys.ECC.generate(:es256)
    {:ok, device_random, xb} = SessionKey.new(key_exchange_format, device_key)

    owner_key = sample_extracted_private_key()

    %{
      key_exchange_format: key_exchange_format,
      cipher_suite_name: cipher_suite_name,
      device_id: device_id,
      device_key: device_key,
      device_random: device_random,
      xb: xb,
      owner_key: owner_key
    }
  end

  setup context do
    %{
      astarte_instance_id: astarte_instance_id,
      realm: realm_name,
      device_id: device_id,
      key_exchange_format: key_exchange_format,
      cipher_suite_name: cipher_suite_name,
      owner_key: owner_key
    } = context

    {:ok, session} =
      Session.new(realm_name, device_id, key_exchange_format, cipher_suite_name, owner_key)

    on_exit(fn ->
      setup_database_access(astarte_instance_id)
      delete_session(realm_name, session.key)
    end)

    %{session: session}
  end

  describe "new/5" do
    test "returns required session information", context do
      %{
        realm: realm_name,
        key_exchange_format: kex,
        device_id: device_id,
        cipher_suite_name: cipher
      } = context

      owner_key = sample_extracted_private_key()
      assert {:ok, session} = Session.new(realm_name, device_id, kex, cipher, owner_key)
      assert is_binary(session.key)
      assert session.prove_dv_nonce
      assert session.owner_random
      assert session.xa
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
      assert is_binary(session.sevk)
    end
  end
end
