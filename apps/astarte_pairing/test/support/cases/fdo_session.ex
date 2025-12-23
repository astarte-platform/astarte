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

    %{session: session}
  end
end
