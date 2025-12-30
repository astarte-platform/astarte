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
  """

  use ExUnit.CaseTemplate

  alias Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.FDO.OwnerOnboarding.SessionKey
  alias COSE.Keys.{ECC, RSA}

  import Astarte.Helpers.Database
  import Astarte.Helpers.FDO

  using do
    quote do
      import Astarte.Helpers.FDO
    end
  end

  setup_all %{realm_name: realm_name} do
    device_id = sample_device_guid()
    hello_device = %{HelloDevice.generate() | device_id: device_id}
    ownership_voucher = sample_ownership_voucher()
    owner_key = sample_extracted_private_key()
    device_key = COSE.Keys.ECC.generate(:es256)
    {:ok, device_random, xb} = SessionKey.new(hello_device.kex_name, device_key)

    insert_voucher(realm_name, sample_private_key(), sample_cbor_voucher(), device_id)

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
      realm_name: realm_name,
      owner_key: owner_key,
      xb: xb
    } = context

    {:ok, session} =
      Session.new(realm_name, hello_device, ownership_voucher, owner_key)

    on_exit(fn ->
      setup_database_access(astarte_instance_id)
      delete_session(realm_name, session.key)
    end)

    {:ok, session} = Session.build_session_secret(session, realm_name, owner_key, xb)
    {:ok, session} = Session.derive_key(session, realm_name)

    # modify session if the test needs a custom set of values for KEX procedures
    custom_kex_session_map = setup_custom_kex_session(context)

    Map.merge(%{session: session}, custom_kex_session_map)
  end

  defp setup_custom_kex_session(context) do
    # generate fresh sets of values to start clean shared secret derivation
    kex_alg = Map.get(context, :kex_name)

    case kex_alg do
      nil ->
        # no KEX modifier applied: use the default session
        %{}

      "ECDH256" ->
        owner_key = ECC.generate(:es256)
        device_key = ECC.generate(:es256)
        {:ok, device_rand, xb} = SessionKey.new("ECDH256", device_key)

        # generate a new consistent session starting from a HelloDevice msg requesting ECDH256
        hello_device_ecdh256 = %{context.hello_device | kex_name: "ECDH256"}

        {:ok, custom_session} =
          Session.new(
            context.realm_name,
            hello_device_ecdh256,
            context.ownership_voucher,
            owner_key
          )

        owner_public_key = parse_xa_ecdh(custom_session.xa, :ec256)

        %{
          session: custom_session,
          device_key: device_key,
          device_rand: device_rand,
          owner_key: owner_key,
          xb: xb,
          owner_public_key: owner_public_key
        }

      "ECDH384" ->
        owner_key = ECC.generate(:es384)
        device_key = ECC.generate(:es384)
        {:ok, device_rand, xb} = SessionKey.new("ECDH384", device_key)

        # generate a new consistent session starting from a HelloDevice msg requesting ECDH384
        hello_device_ecdh384 = %{context.hello_device | kex_name: "ECDH384"}

        {:ok, custom_session} =
          Session.new(
            context.realm_name,
            hello_device_ecdh384,
            context.ownership_voucher,
            owner_key
          )

        owner_public_key = parse_xa_ecdh(custom_session.xa, :ec384)

        %{
          session: custom_session,
          device_key: device_key,
          device_rand: device_rand,
          owner_key: owner_key,
          xb: xb,
          owner_public_key: owner_public_key
        }

      "DHKEXid14" ->
        owner_key = RSA.generate(:rs256)
        {:ok, device_rand, xb} = SessionKey.new("DHKEXid14", :nokey)

        # generate a new consistent session starting from a HelloDevice msg requesting DHKEXid14
        hello_device_dhkex14 = %{context.hello_device | kex_name: "DHKEXid14"}

        {:ok, custom_session} =
          Session.new(
            context.realm_name,
            hello_device_dhkex14,
            context.ownership_voucher,
            owner_key
          )

        %{
          session: custom_session,
          device_rand: device_rand,
          xb: xb
        }

      "DHKEXid15" ->
        owner_key = RSA.generate(:rs384)
        {:ok, device_rand, xb} = SessionKey.new("DHKEXid15", :nokey)

        # generate a new consistent session starting from a HelloDevice msg requesting DHKEXid15
        hello_device_dhkex15 = %{context.hello_device | kex_name: "DHKEXid15"}

        {:ok, custom_session} =
          Session.new(
            context.realm_name,
            hello_device_dhkex15,
            context.ownership_voucher,
            owner_key
          )

        %{
          session: custom_session,
          device_rand: device_rand,
          xb: xb
        }
    end
  end

  defp parse_xa_ecdh(xa, alg_type) do
    {x_bytesize, y_bytesize, rand_bytesize} =
      case alg_type do
        :ec256 ->
          {32, 32, 16}

        :ec384 ->
          {48, 48, 48}
      end

    <<_::binary-size(2), x::binary-size(x_bytesize), _::binary-size(2),
      y::binary-size(y_bytesize), _rest::binary-size(2 + rand_bytesize)>> = xa

    # derived owner public key
    <<4, x::binary, y::binary>>
  end
end
