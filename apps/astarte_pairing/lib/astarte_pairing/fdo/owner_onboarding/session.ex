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

defmodule Astarte.Pairing.FDO.OwnerOnboarding.Session do
  use TypedStruct

  alias Astarte.DataAccess.FDO.TO2Session
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.FDO.OwnerOnboarding.SessionKey
  alias Astarte.Pairing.Queries

  typedstruct do
    field :key, String.t()
    field :device_id, Astarte.DataAccess.UUID
    field :device_public_key, binary()
    field :prove_ov_nonce, binary()
    field :kex_suite_name, String.t()
    field :owner_random, term()
    field :xa, binary()
    field :secret, binary()
  end

  def new(realm_name, device_id, kex, owner_key) do
    key = UUID.uuid4(:raw)
    prove_ov_nonce = :crypto.strong_rand_bytes(16)

    with {:ok, owner_random, xa} <- SessionKey.new(kex, owner_key),
         :ok <-
           Queries.store_session(
             realm_name,
             device_id,
             key,
             prove_ov_nonce,
             kex,
             owner_random
           ) do
      session = %Session{
        key: UUID.binary_to_string!(key),
        device_id: device_id,
        prove_ov_nonce: prove_ov_nonce,
        kex_suite_name: kex,
        owner_random: owner_random,
        xa: xa
      }

      {:ok, session}
    end
  end

  def build_session_secret(session, realm_name, owner_key, xb) do
    %Session{kex_suite_name: kex, owner_random: owner_random, key: session_key} = session

    with {:ok, device_public, secret} <-
           SessionKey.compute_shared_secret(kex, owner_key, owner_random, xb),
         :ok <- Queries.add_session_secret(realm_name, session_key, device_public, secret) do
      {:ok, %{session | secret: secret, device_public_key: device_public}}
    end
  end

  def fetch(realm_name, session_key) do
    with {:ok, database_session} <- Queries.fetch_session(realm_name, session_key) do
      %TO2Session{
        device_id: device_id,
        device_public_key: device_public_key,
        prove_ov_nonce: prove_ov_nonce,
        kex_suite_name: kex_suite_name,
        owner_random: owner_random,
        secret: secret
      } = database_session

      session = %Session{
        key: session_key,
        device_id: device_id,
        device_public_key: device_public_key,
        prove_ov_nonce: prove_ov_nonce,
        kex_suite_name: kex_suite_name,
        owner_random: owner_random,
        secret: secret
      }

      {:ok, session}
    end
  end
end
