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
  alias Astarte.Pairing.FDO.OwnerOnboarding.HelloDevice
  alias Astarte.Pairing.FDO.OwnerOnboarding.SignatureInfo
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.FDO.OwnerOnboarding.SessionKey
  alias Astarte.Pairing.Queries
  alias COSE.Messages.Encrypt0

  typedstruct do
    field :key, String.t()
    field :device_id, Astarte.DataAccess.UUID
    field :device_signature, SignatureInfo.device_signature()
    field :prove_dv_nonce, binary()
    field :kex_suite_name, String.t()
    field :cipher_suite, String.t()
    field :owner_random, term()
    field :xa, binary()
    field :secret, binary() | nil
    field :sevk, struct() | nil
    field :svk, struct() | nil
    field :sek, struct() | nil
  end

  def new(realm_name, hello_device, ownership_voucher, owner_key) do
    key = UUID.uuid4(:raw)
    prove_dv_nonce = :crypto.strong_rand_bytes(16)

    %HelloDevice{
      kex_name: kex,
      device_id: device_id,
      easig_info: easig_info,
      cipher_name: cipher_suite_name
    } = hello_device

    with {:ok, owner_random, xa} <- SessionKey.new(kex, owner_key),
         {:ok, device_signature} <- SignatureInfo.validate(easig_info, ownership_voucher),
         signature_params = SignatureInfo.device_signature_to_database_params(device_signature),
         session_params = %TO2Session{
           device_id: device_id,
           prove_dv_nonce: prove_dv_nonce,
           kex_suite_name: kex,
           cipher_suite_name: cipher_suite_name,
           owner_random: owner_random
         },
         session_params = Map.merge(session_params, signature_params),
         :ok <-
           Queries.store_session(
             realm_name,
             key,
             session_params
           ) do
      session = %Session{
        key: UUID.binary_to_string!(key),
        device_id: device_id,
        prove_dv_nonce: prove_dv_nonce,
        kex_suite_name: kex,
        cipher_suite: cipher_suite_name,
        owner_random: owner_random,
        xa: xa,
        device_signature: device_signature
      }

      {:ok, session}
    end
  end

  def build_session_secret(session, realm_name, owner_key, xb) do
    %Session{kex_suite_name: kex, owner_random: owner_random, key: session_key} = session

    with {:ok, secret} <-
           SessionKey.compute_shared_secret(kex, owner_key, owner_random, xb),
         :ok <- Queries.add_session_secret(realm_name, session_key, secret) do
      {:ok, %{session | secret: secret}}
    end
  end

  def derive_key(session, realm_name) do
    %Session{
      cipher_suite: cipher_suite,
      secret: secret,
      owner_random: owner_random,
      key: session_key
    } = session

    with {:ok, sevk, svk, sek} <- SessionKey.derive_key(cipher_suite, secret, owner_random),
         [db_sevk, db_svk, db_sek] = Enum.map([sevk, svk, sek], &SessionKey.to_db/1),
         :ok <- Queries.add_session_keys(realm_name, session_key, db_sevk, db_svk, db_sek) do
      {:ok, %{session | sevk: sevk, svk: svk, sek: sek}}
    end
  end

  def decrypt_and_verify(%Session{sevk: sevk}, message) when not is_nil(sevk) do
    cipher = sevk.alg

    with {:ok, enc0} <- Encrypt0.decrypt_decode(message, cipher, sevk),
         {:ok, body, _} <- CBOR.decode(enc0.payload) do
      {:ok, body}
    else
      _ -> :error
    end
  end

  def fetch(realm_name, session_key) do
    with {:ok, database_session} <- Queries.fetch_session(realm_name, session_key),
         {:ok, device_signature} <-
           SignatureInfo.database_params_to_device_signature(database_session) do
      %TO2Session{
        device_id: device_id,
        prove_dv_nonce: prove_dv_nonce,
        kex_suite_name: kex_suite_name,
        cipher_suite_name: cipher_suite_name,
        owner_random: owner_random,
        secret: secret,
        sevk: sevk,
        svk: svk,
        sek: sek
      } = database_session

      session = %Session{
        key: session_key,
        device_id: device_id,
        prove_dv_nonce: prove_dv_nonce,
        kex_suite_name: kex_suite_name,
        cipher_suite: cipher_suite_name,
        owner_random: owner_random,
        device_signature: device_signature,
        secret: secret,
        sevk: SessionKey.from_db(sevk),
        svk: SessionKey.from_db(svk),
        sek: SessionKey.from_db(sek)
      }

      {:ok, session}
    end
  end
end
