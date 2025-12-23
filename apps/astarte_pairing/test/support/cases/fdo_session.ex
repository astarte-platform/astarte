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

defmodule Astarte.Cases.FDOSession do
  @moduledoc """
  This module defines the setup for tests requiring an FDO session with
  a fully initialized session including derived keys.

  This provides:
  - A HelloDevice instance
  - An ownership voucher
  - Owner and device keys
  - A Session with derived session keys (SEVK)
  - Automatic cleanup of the session on test exit

  Using ExUnit test tags it is possible to add customizations to the test setup
  (e.g. creating the context with non-default owner key and voucher).
  """

  use ExUnit.CaseTemplate

  alias Astarte.Pairing.FDO.OwnershipVoucher
  alias Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.FDO.OwnerOnboarding.SessionKey
  alias Astarte.Pairing.FDO.OwnerOnboarding.KeyExchangeStrategy
  alias COSE.Keys.{ECC, RSA}

  import Astarte.Helpers.Database
  import Astarte.Helpers.FDO

  using do
    quote do
      import Astarte.Helpers.FDO
    end
  end

  @allowed_owner_key_tag_values ["EC256", "EC384", "RSA2048", "RSA3072"]
  @allowed_kex_name_tag_values [
    "ECDH256",
    "ECDH384",
    "DHKEXid14",
    "DHKEXid15",
    "ASYMKEX2048",
    "ASYMKEX3072"
  ]

  setup context do
    # setup block for owner/device keys & ownership voucher
    # use test tag 'owner_key' to select non-default keys
    # default: EC256 keys
    key_type = Map.get(context, :owner_key, "EC256")

    if key_type not in @allowed_owner_key_tag_values,
      do: raise("unsupported owner_key tag value: #{key_type}")

    {owner_key_struct, device_key, ownership_voucher} = generate_keys_and_voucher(key_type)
    owner_key_pem = COSE.Keys.to_pem(owner_key_struct)
    cbor_ownership_voucher = OwnershipVoucher.cbor_encode(ownership_voucher)
    device_id = Astarte.Core.Device.random_device_id()

    insert_voucher(
      context.realm_name,
      owner_key_pem,
      cbor_ownership_voucher,
      device_id
    )

    %{
      owner_key: owner_key_struct,
      owner_key_pem: owner_key_pem,
      ownership_voucher: ownership_voucher,
      cbor_ownership_voucher: cbor_ownership_voucher,
      device_id: device_id,
      device_key: device_key
    }
  end

  setup context do
    # setup block for FDO Session
    # use test tag 'kex_name' to select non-default KEX algorithm
    # default: ECDH256 key exchange
    kex_name = Map.get(context, :kex_name, "ECDH256")

    if kex_name not in @allowed_kex_name_tag_values,
      do: raise("unsupported kex_name tag value: #{kex_name}")

    if KeyExchangeStrategy.validate(kex_name, context.owner_key) != :ok,
      do:
        raise(
          "unsupported association owner key type #{context.owner_key.alg} <-> KEX alg #{kex_name}"
        )

    {:ok, device_random, xb} =
      generate_xb_key_exchange(kex_name, context.device_key, context.owner_key)

    hello_device =
      HelloDevice.generate(
        kex_name: kex_name,
        easig_info: context.device_key.alg,
        device_id: context.device_id
      )

    {:ok, session} =
      Session.new(
        context.realm_name,
        hello_device,
        context.ownership_voucher,
        context.owner_key
      )

    on_exit(fn ->
      setup_database_access(context.astarte_instance_id)
      delete_session(context.realm_name, session.key)
    end)

    {:ok, session} =
      Session.build_session_secret(session, context.realm_name, context.owner_key, xb)

    {:ok, session} = Session.derive_key(session, context.realm_name)

    %{hello_device: hello_device, session: session, device_random: device_random, xb: xb}
  end

  defp generate_keys_and_voucher(key_type) do
    case key_type do
      "EC256" ->
        owner_key = ECC.generate(:es256)
        device_key = ECC.generate(:es256)
        {voucher, _} = generate_voucher_data_and_pem(curve: :p256, device_key: device_key)
        {owner_key, device_key, voucher}

      "EC384" ->
        owner_key = ECC.generate(:es384)
        device_key = ECC.generate(:es384)
        {voucher, _} = generate_voucher_data_and_pem(curve: :p384, device_key: device_key)
        {owner_key, device_key, voucher}

      "RSA2048" ->
        owner_key = RSA.generate(:rs256)
        device_key = ECC.generate(:es256)
        {voucher, _} = generate_voucher_data_and_pem(curve: :p256, device_key: device_key)
        {owner_key, device_key, voucher}

      "RSA3072" ->
        owner_key = RSA.generate(:rs384)
        device_key = ECC.generate(:es384)
        {voucher, _} = generate_voucher_data_and_pem(curve: :p384, device_key: device_key)
        {owner_key, device_key, voucher}
    end
  end

  defp generate_xb_key_exchange(kex_name, device_key, owner_key) do
    case kex_name do
      kn when kn in ["ECDH256", "ECDH384", "DHKEXid14", "DHKEXid15"] ->
        SessionKey.new(kn, device_key)

      kn when kn in ["ASYMKEX2048", "ASYMKEX3072"] ->
        {:ok, device_rand, _} = SessionKey.new(kn, :nokey)
        # Owner RSA key used to encrypt/decrypt device rand
        pub_key_record = owner_key |> RSA.to_public_record()
        xb = asymkex_msg_encryption(device_rand, pub_key_record)
        {:ok, device_rand, xb}
    end
  end

  defp asymkex_msg_encryption(msg, pub_rsa_key) do
    encrypt_opts = [
      rsa_padding: :rsa_pkcs1_oaep_padding,
      rsa_oaep_md: :sha256,
      rsa_mgf1_md: :sha256
    ]

    :public_key.encrypt_public(msg, pub_rsa_key, encrypt_opts)
  end
end
