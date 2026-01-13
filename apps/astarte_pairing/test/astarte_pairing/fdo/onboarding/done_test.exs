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

defmodule Astarte.Pairing.FDO.Onboarding.DoneTest do
  use Astarte.Cases.Data, async: false
  use Astarte.Cases.FDOSession

  import Ecto.Query

  alias Astarte.Core.Device
  alias Astarte.Pairing.FDO.OwnerOnboarding
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.Queries
  alias Astarte.DataAccess.Devices.Device, as: DeviceDB
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias Astarte.Pairing.FDO.Types.Hash

  @wrong_prove_dv_nonce :crypto.strong_rand_bytes(16)

  defp get_device_ttl(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from d in DeviceDB,
        where: d.device_id == ^device_id,
        select: fragment("TTL(?)", d.first_registration)

    Repo.one(query, prefix: keyspace)
  end

  setup %{realm: realm_name, session: session} do
    setup_dv_nonce = :crypto.strong_rand_bytes(16)
    device_id = Device.random_device_id()

    with {:ok, session_with_setup_nonce} <-
           Session.add_setup_dv_nonce(session, realm_name, setup_dv_nonce),
         {:ok, session_with_device_id} <-
           Session.add_device_id(session_with_setup_nonce, realm_name, device_id) do
      encoded_device_id = Device.encode_device_id(device_id)
      Astarte.Pairing.Engine.register_device(realm_name, encoded_device_id, unconfirmed: true)
      %{session: session_with_device_id}
    end
  end

  describe "done/3" do
    test "returns {:ok, cbor_binary} (containing SetupDv nonce) when ProveDv nonces match", %{
      realm: realm_name,
      session: session
    } do
      done_msg = [%CBOR.Tag{tag: :bytes, value: session.prove_dv_nonce}]

      {:ok, ownership_voucher} = OwnershipVoucher.fetch(realm_name, session.guid)
      {:ok, owner_public_key} = OwnershipVoucher.owner_public_key(ownership_voucher)
      rendezvous_info = ownership_voucher.header.rendezvous_info
      new_hmac = :crypto.strong_rand_bytes(32)

      session = %{
        session
        | replacement_guid: session.guid,
          replacement_hmac: %Hash{hash: new_hmac, type: :hmac_sha256},
          replacement_rv_info: rendezvous_info,
          replacement_pub_key: owner_public_key
      }

      {:ok, done2_msg_cbor} = OwnerOnboarding.done(realm_name, session, done_msg)

      assert {:ok, [%CBOR.Tag{tag: :bytes, value: setup_nonce}], _} =
               CBOR.decode(done2_msg_cbor)

      assert setup_nonce == session.setup_dv_nonce
    end

    test "ensure new voucher is saved when ProveDv nonces match and TO2.done ends successfully ",
         %{
           realm: realm_name,
           session: session
         } do
      {:ok, ownership_voucher} = OwnershipVoucher.fetch(realm_name, session.guid)
      {:ok, owner_public_key} = OwnershipVoucher.owner_public_key(ownership_voucher)
      rendezvous_info = ownership_voucher.header.rendezvous_info

      session = %{
        session
        | replacement_guid: session.guid,
          replacement_hmac: nil,
          replacement_rv_info: rendezvous_info,
          replacement_pub_key: owner_public_key
      }

      done_msg = [%CBOR.Tag{tag: :bytes, value: session.prove_dv_nonce}]
      {:ok, old_voucher} = OwnershipVoucher.fetch(realm_name, session.guid)
      {:ok, _} = OwnerOnboarding.done(realm_name, session, done_msg)

      {:ok, voucher} = OwnershipVoucher.fetch(realm_name, session.guid)

      assert voucher.entries == old_voucher.entries
      assert voucher.hmac == old_voucher.hmac
    end

    test "ensure old voucher is keep when ProveDv nonces match and TO2.done ends successfully without credential reuse ",
         %{
           realm: realm_name,
           session: session
         } do
      {:ok, ownership_voucher} = OwnershipVoucher.fetch(realm_name, session.guid)
      {:ok, owner_public_key} = OwnershipVoucher.owner_public_key(ownership_voucher)
      rendezvous_info = ownership_voucher.header.rendezvous_info
      new_hmac = :crypto.strong_rand_bytes(32)

      session = %{
        session
        | replacement_guid: session.guid,
          replacement_hmac: %Hash{hash: new_hmac, type: :hmac_sha256},
          replacement_rv_info: rendezvous_info,
          replacement_pub_key: owner_public_key
      }

      done_msg = [%CBOR.Tag{tag: :bytes, value: session.prove_dv_nonce}]
      {:ok, old_voucher} = OwnershipVoucher.fetch(realm_name, session.guid)
      {:ok, _} = OwnerOnboarding.done(realm_name, session, done_msg)

      {:ok, voucher} = OwnershipVoucher.fetch(realm_name, session.guid)

      assert voucher.entries == []

      assert voucher.hmac != old_voucher.hmac
    end

    test "returns {:error, :invalid_message} when the ProveDv nonces don't match", %{
      realm: realm_name,
      session: session
    } do
      mismatch_msg = [%CBOR.Tag{tag: :bytes, value: @wrong_prove_dv_nonce}]

      assert {:error, :invalid_message} =
               OwnerOnboarding.done(realm_name, session, mismatch_msg)
    end

    test "removes device TTL when onboarding completes successfully", %{
      realm: realm_name,
      session: session
    } do
      {:ok, ownership_voucher} = OwnershipVoucher.fetch(realm_name, session.guid)
      {:ok, owner_public_key} = OwnershipVoucher.owner_public_key(ownership_voucher)
      rendezvous_info = ownership_voucher.header.rendezvous_info
      new_hmac = :crypto.strong_rand_bytes(32)

      session = %{
        session
        | replacement_guid: session.guid,
          replacement_hmac: %Hash{hash: new_hmac, type: :hmac_sha256},
          replacement_rv_info: rendezvous_info,
          replacement_pub_key: owner_public_key
      }

      done_msg = [%CBOR.Tag{tag: :bytes, value: session.prove_dv_nonce}]

      {:ok, device_before} = Queries.fetch_device(realm_name, session.device_id)
      assert device_before.device_id == session.device_id

      ttl_before = get_device_ttl(realm_name, session.device_id)
      assert is_integer(ttl_before) and ttl_before > 0

      assert {:ok, _} = OwnerOnboarding.done(realm_name, session, done_msg)

      {:ok, device_after} = Queries.fetch_device(realm_name, session.device_id)
      assert device_after.device_id == session.device_id
      assert device_after.credentials_secret == device_before.credentials_secret
      assert device_after.first_registration == device_before.first_registration

      ttl_after = get_device_ttl(realm_name, session.device_id)

      assert ttl_after == nil,
             "TTL should be nil (no TTL/permanent) after removal, got #{inspect(ttl_after)}"
    end

    test "returns error when device doesn't exist in database", %{
      realm: realm_name,
      session: session
    } do
      keyspace = Realm.keyspace_name(realm_name)
      Repo.delete(%DeviceDB{device_id: session.device_id}, prefix: keyspace)

      done_msg = [%CBOR.Tag{tag: :bytes, value: session.prove_dv_nonce}]

      assert {:error, :device_not_found} =
               OwnerOnboarding.done(realm_name, session, done_msg)
    end
  end
end
