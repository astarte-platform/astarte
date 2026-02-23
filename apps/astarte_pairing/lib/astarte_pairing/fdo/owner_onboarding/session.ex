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
  alias Astarte.Pairing.FDO.OwnerOnboarding.OwnerServiceInfo
  alias Astarte.Pairing.FDO.OwnerOnboarding.SignatureInfo
  alias Astarte.Pairing.FDO.OwnerOnboarding.Session
  alias Astarte.Pairing.FDO.OwnerOnboarding.SessionKey
  alias Astarte.Pairing.FDO.OwnerOnboarding.SessionToken
  alias Astarte.Pairing.FDO.OwnershipVoucher.RendezvousInfo
  alias Astarte.Pairing.FDO.Types.Hash
  alias Astarte.Pairing.FDO.Types.PublicKey
  alias Astarte.Pairing.Queries
  alias COSE.Messages.Encrypt0

  typedstruct do
    field :guid, binary()
    field :hmac, Hash.t()
    field :device_id, Astarte.DataAccess.UUID, default: nil
    field :nonce, binary()
    field :device_signature, SignatureInfo.device_signature()
    field :prove_dv_nonce, binary()
    field :setup_dv_nonce, binary()
    field :kex_suite_name, String.t()
    field :cipher_suite, String.t()
    field :owner_random, term()
    field :xa, binary()
    field :secret, binary() | nil
    field :sevk, struct() | nil
    field :svk, struct() | nil
    field :sek, struct() | nil
    field :max_owner_service_info_size, integer() | nil
    field :device_service_info, map() | nil
    field :owner_service_info, [binary()] | nil
    field :last_chunk_sent, non_neg_integer() | nil
    field :replacement_guid, binary() | nil
    field :replacement_rv_info, RendezvousInfo.t() | nil
    field :replacement_pub_key, PublicKey.t() | nil
    field :replacement_hmac, Hash.t() | nil
  end

  def new(realm_name, hello_device, ownership_voucher, owner_key, hmac) do
    prove_dv_nonce = :crypto.strong_rand_bytes(16)
    nonce = :crypto.strong_rand_bytes(16)

    %HelloDevice{
      guid: guid,
      easig_info: easig_info,
      cipher_name: cipher_suite_name,
      kex_name: kex_name
    } = hello_device

    with {:ok, owner_random, xa} <- SessionKey.new(kex_name, owner_key),
         {:ok, device_signature} <-
           SignatureInfo.validate(easig_info, ownership_voucher),
         signature_params =
           SignatureInfo.device_signature_to_database_params(device_signature),
         session_params =
           %TO2Session{
             guid: guid,
             device_id: nil,
             hmac: Hash.encode_cbor(hmac),
             nonce: nonce,
             prove_dv_nonce: prove_dv_nonce,
             kex_suite_name: kex_name,
             cipher_suite_name: cipher_suite_name,
             owner_random: owner_random
           },
         session_params = Map.merge(session_params, signature_params),
         :ok <-
           Queries.store_session(
             realm_name,
             guid,
             session_params
           ) do
      token = SessionToken.generate(guid, nonce)

      session =
        %Session{
          guid: guid,
          hmac: hmac,
          device_id: nil,
          nonce: nonce,
          prove_dv_nonce: prove_dv_nonce,
          kex_suite_name: kex_name,
          cipher_suite: cipher_suite_name,
          owner_random: owner_random,
          xa: xa,
          device_signature: device_signature
        }

      {:ok, token, session}
    end
  end

  def add_setup_dv_nonce(session, realm_name, setup_dv_nonce) do
    with :ok <- Queries.session_add_setup_dv_nonce(realm_name, session.guid, setup_dv_nonce) do
      {:ok, %{session | setup_dv_nonce: setup_dv_nonce}}
    end
  end

  def add_max_owner_service_info_size(session, realm_name, size) do
    with :ok <-
           Queries.add_session_max_owner_service_info_size(realm_name, session.guid, size) do
      {:ok, %{session | max_owner_service_info_size: size}}
    end
  end

  def add_owner_service_info(session, realm_name, owner_service_info) do
    with :ok <-
           Queries.session_add_owner_service_info(
             realm_name,
             session.guid,
             owner_service_info
           ) do
      {:ok, %{session | owner_service_info: owner_service_info}}
    end
  end

  def next_owner_service_info_chunk(session, realm_name) do
    case get_next_owner_chunk(session) do
      {:ok, index, service_info_chunk} ->
        with :ok <-
               Queries.session_update_last_chunk_sent(
                 realm_name,
                 session.guid,
                 index
               ) do
          {:ok, %{session | last_chunk_sent: index}, service_info_chunk}
        end

      :done ->
        {:ok, session, OwnerServiceInfo.empty()}
    end
  end

  defp get_next_owner_chunk(%{owner_service_info: chunks, last_chunk_sent: last}) do
    next_index = (last || -1) + 1

    case Enum.at(chunks, next_index) do
      nil ->
        :done

      chunk ->
        {:ok, next_index, chunk}
    end
  end

  def add_device_id(session, realm_name, device_id) do
    with :ok <- Queries.session_update_device_id(realm_name, session.guid, device_id) do
      {:ok, %{session | device_id: device_id}}
    end
  end

  def add_device_service_info(session, realm_name, new_service_info) do
    service_info = encode_values_to_cbor(new_service_info)
    session = update_in(session.device_service_info, &Map.merge(&1 || %{}, service_info))

    with :ok <-
           Queries.session_add_device_service_info(
             realm_name,
             session.guid,
             session.device_service_info
           ) do
      {:ok, session}
    end
  end

  defp encode_values_to_cbor(map) when is_map(map) do
    Map.new(map, fn
      {key, value} ->
        {key, CBOR.encode(value)}
    end)
  end

  def add_replacement_info(session, realm_name, replacement_guid, rv_info, pub_key, hmac) do
    with :ok <-
           Queries.session_add_replacement_info(
             realm_name,
             session.guid,
             replacement_guid,
             rv_info,
             pub_key,
             hmac
           ) do
      {:ok,
       %{
         session
         | replacement_guid: replacement_guid,
           replacement_rv_info: rv_info,
           replacement_pub_key: pub_key,
           replacement_hmac: hmac
       }}
    end
  end

  def build_session_secret(session, realm_name, owner_key, xb) do
    %Session{kex_suite_name: kex, owner_random: owner_random, guid: guid} = session

    with {:ok, secret} <-
           SessionKey.compute_shared_secret(kex, owner_key, owner_random, xb),
         :ok <- Queries.add_session_secret(realm_name, guid, secret) do
      {:ok, %{session | secret: secret}}
    end
  end

  def derive_key(session, realm_name) do
    %Session{
      kex_suite_name: kex_suite_name,
      cipher_suite: cipher_suite,
      secret: secret,
      owner_random: owner_random,
      guid: guid
    } = session

    with {:ok, sevk, svk, sek} <-
           SessionKey.derive_key(kex_suite_name, cipher_suite, secret, owner_random),
         [db_sevk, db_svk, db_sek] = Enum.map([sevk, svk, sek], &SessionKey.to_db/1),
         :ok <- Queries.add_session_keys(realm_name, guid, db_sevk, db_svk, db_sek) do
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

  def encrypt_and_sign(%Session{sevk: sevk}, message) when not is_nil(sevk) do
    cipher = sevk.alg
    iv = :crypto.strong_rand_bytes(12)
    protected_headers = %{alg: cipher}
    unprotected_headers = %{iv: COSE.tag_as_byte(iv)}

    Encrypt0.build(message, protected_headers, unprotected_headers)
    |> Encrypt0.encrypt_encode(cipher, sevk, iv)
  end

  def fetch(realm_name, guid) do
    with {:ok, database_session} <- Queries.fetch_session(realm_name, guid),
         {:ok, device_signature} <-
           SignatureInfo.database_params_to_device_signature(database_session) do
      %TO2Session{
        guid: guid,
        device_id: device_id,
        hmac: db_hmac,
        nonce: db_nonce,
        prove_dv_nonce: prove_dv_nonce,
        setup_dv_nonce: setup_dv_nonce,
        kex_suite_name: kex_suite_name,
        cipher_suite_name: cipher_suite_name,
        owner_random: owner_random,
        secret: secret,
        sevk: sevk,
        svk: svk,
        sek: sek,
        max_owner_service_info_size: max_owner_service_info_size,
        device_service_info: device_service_info,
        owner_service_info: owner_service_info,
        last_chunk_sent: last_chunk_sent,
        replacement_guid: replacement_guid,
        replacement_rv_info: replacement_rv_info,
        replacement_pub_key: replacement_pub_key,
        replacement_hmac: replacement_hmac
      } = database_session

      {:ok, hmac} = Hash.decode_cbor(db_hmac)

      session = %Session{
        guid: guid,
        device_id: device_id,
        hmac: hmac,
        nonce: db_nonce,
        prove_dv_nonce: prove_dv_nonce,
        setup_dv_nonce: setup_dv_nonce,
        kex_suite_name: kex_suite_name,
        cipher_suite: cipher_suite_name,
        owner_random: owner_random,
        device_signature: device_signature,
        secret: secret,
        sevk: SessionKey.from_db(sevk),
        svk: SessionKey.from_db(svk),
        sek: SessionKey.from_db(sek),
        max_owner_service_info_size: max_owner_service_info_size,
        device_service_info: device_service_info,
        owner_service_info: owner_service_info,
        last_chunk_sent: last_chunk_sent,
        replacement_guid: replacement_guid,
        replacement_rv_info: replacement_rv_info,
        replacement_pub_key: replacement_pub_key,
        replacement_hmac: replacement_hmac
      }

      {:ok, session}
    end
  end
end
