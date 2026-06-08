#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.Pairing.Queries do
  @moduledoc """
  This module is responsible for the interaction with the database.
  """

  import Ecto.Query

  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.DataAccess.FDO.OwnershipVoucher
  alias Astarte.DataAccess.FDO.TO2Session
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  require Logger

  def realm_existing?(realm_name) do
    keyspace_name = Realm.astarte_keyspace_name()

    query =
      from r in Realm,
        prefix: ^keyspace_name,
        where: r.realm_name == ^realm_name,
        select: count()

    consistency = Consistency.domain_model(:read)

    case Repo.safe_fetch_one(query, consistency: consistency) do
      {:ok, count} ->
        {:ok, count > 0}

      {:error, reason} ->
        Logger.warning("Cannot check if realm exists: #{inspect(reason)}.",
          tag: "realm_existing_error",
          realm: realm_name
        )

        {:error, reason}
    end
  end

  def get_agent_public_key_pems(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    with {:ok, pem} <-
           KvStore.fetch_value("auth", "jwt_public_key_pem", :string,
             prefix: keyspace,
             consistency: Consistency.domain_model(:read),
             error: :public_key_not_found
           ) do
      {:ok, [pem]}
    end
  end

  def unregister_device(realm_name, device_id) do
    with {:ok, device} <- Astarte.DataAccess.Device.fetch(realm_name, device_id),
         {:ok, _device} <- do_unregister_device(realm_name, device) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("Unregister error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def check_already_registered_device(realm_name, device_id) do
    keyspace_name = Realm.keyspace_name(realm_name)

    consistency = Consistency.device_info(:read)

    case Repo.get(Device, device_id, prefix: keyspace_name, consistency: consistency) do
      %Device{} -> true
      nil -> false
    end
  end

  defp do_unregister_device(realm_name, %Device{} = device) do
    keyspace_name = Realm.keyspace_name(realm_name)

    consistency = Consistency.device_info(:write)

    device
    |> Ecto.Changeset.change(
      first_credentials_request: nil,
      credentials_secret: nil
    )
    |> Repo.update(prefix: keyspace_name, consistency: consistency)
  end

  def update_device_after_credentials_request(realm_name, device, cert_data, device_ip, nil) do
    first_credentials_request_timestamp = DateTime.utc_now()

    update_device_after_credentials_request(
      realm_name,
      device,
      cert_data,
      device_ip,
      first_credentials_request_timestamp
    )
  end

  def update_device_after_credentials_request(
        realm_name,
        %Device{} = device,
        %{serial: serial, aki: aki} = _cert_data,
        device_ip,
        %DateTime{} = first_credentials_request_timestamp
      ) do
    keyspace_name = Realm.keyspace_name(realm_name)

    consistency = Consistency.device_info(:write)

    device
    |> Ecto.Changeset.change(%{
      cert_aki: aki,
      cert_serial: serial,
      last_credentials_request_ip: device_ip,
      first_credentials_request: first_credentials_request_timestamp
    })
    |> Repo.update(prefix: keyspace_name, consistency: consistency)
  end

  def remove_device_ttl(realm_name, device_id) do
    keyspace_name = Realm.keyspace_name(realm_name)
    consistency = Consistency.device_info(:write)

    with {:ok, device} <- Astarte.DataAccess.Device.fetch(realm_name, device_id) do
      device
      |> Repo.insert(
        prefix: keyspace_name,
        consistency: consistency
      )
    end
  end

  def fetch_device_registration_limit(realm_name) do
    keyspace = Realm.astarte_keyspace_name()

    consistency = Consistency.domain_model(:read)

    case Repo.fetch(Realm, realm_name,
           prefix: keyspace,
           consistency: consistency,
           error: :realm_not_found
         ) do
      {:ok, realm} ->
        {:ok, realm.device_registration_limit}

      {:error, :realm_not_found} ->
        Logger.warning(
          "cannot fetch device registration limit: realm #{realm_name} not found",
          tag: "realm_not_found"
        )

        {:error, :realm_not_found}
    end
  end

  def fetch_registered_devices_count(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    consistency = Consistency.device_info(:read)

    count =
      Device
      |> select([d], count())
      |> Repo.one!(prefix: keyspace, consistency: consistency)

    {:ok, count}
  end

  def get_ownership_voucher(realm_name, guid) do
    keyspace_name = Realm.keyspace_name(realm_name)

    query =
      from o in OwnershipVoucher,
        prefix: ^keyspace_name,
        select: o.voucher_data

    consistency = Consistency.domain_model(:read)

    Repo.fetch(query, guid, consistency: consistency)
  end

  def get_owner_private_key(realm_name, guid) do
    keyspace_name = Realm.keyspace_name(realm_name)

    query =
      from o in OwnershipVoucher,
        prefix: ^keyspace_name,
        select: o.key_name

    consistency = Consistency.domain_model(:read)

    Repo.fetch(query, guid, consistency: consistency)
  end

  def create_ownership_voucher(
        realm_name,
        guid,
        cbor_ownership_voucher,
        key_name,
        ttl
      ) do
    keyspace_name = Realm.keyspace_name(realm_name)

    opts = [prefix: keyspace_name, consistency: Consistency.device_info(:write), ttl: ttl]

    %OwnershipVoucher{
      voucher_data: cbor_ownership_voucher,
      key_name: key_name,
      guid: guid
    }
    |> Repo.insert(opts)
  end

  def delete_ownership_voucher(realm_name, guid) do
    keyspace = Realm.keyspace_name(realm_name)

    %OwnershipVoucher{
      guid: guid
    }
    |> Repo.delete(prefix: keyspace)
  end

  def replace_ownership_voucher(
        realm_name,
        guid,
        new_voucher
      ) do
    keyspace = Realm.keyspace_name(realm_name)
    consistency = Consistency.device_info(:write)
    opts = [prefix: keyspace, consistency: consistency]

    %OwnershipVoucher{guid: guid}
    |> Ecto.Changeset.change(output_voucher: new_voucher)
    |> Repo.update(opts)
  end

  def store_session(realm_name, guid, session) do
    keyspace = Realm.keyspace_name(realm_name)
    consistency = Consistency.device_info(:write)
    opts = [prefix: keyspace, consistency: consistency]

    session = %{session | guid: guid}

    with {:ok, _} <- Repo.insert(session, opts) do
      :ok
    end
  end

  def add_session_max_owner_service_info_size(realm_name, guid, size) do
    updates = [max_owner_service_info_size: size]
    update_session(realm_name, guid, updates)
  end

  def add_session_secret(realm_name, guid, secret) do
    updates = [secret: secret]
    update_session(realm_name, guid, updates)
  end

  def add_session_keys(realm_name, guid, sevk, svk, sek) do
    updates = [sevk: sevk, svk: svk, sek: sek]
    update_session(realm_name, guid, updates)
  end

  def session_add_setup_dv_nonce(realm_name, guid, setup_dv_nonce) do
    updates = [setup_dv_nonce: setup_dv_nonce]
    update_session(realm_name, guid, updates)
  end

  def session_update_device_id(realm_name, guid, device_id) do
    updates = [device_id: device_id]
    update_session(realm_name, guid, updates)
  end

  def session_add_device_service_info(realm_name, guid, service_info) do
    updates = [device_service_info: service_info]
    update_session(realm_name, guid, updates)
  end

  def session_add_owner_service_info(realm_name, guid, owner_service_info) do
    updates = [owner_service_info: owner_service_info]
    update_session(realm_name, guid, updates)
  end

  def session_update_last_chunk_sent(realm_name, guid, last_chunk) do
    updates = [last_chunk_sent: last_chunk]
    update_session(realm_name, guid, updates)
  end

  def session_add_replacement_info(realm_name, guid, replacement_guid, rv_info, pub_key, hmac) do
    updates = [
      replacement_guid: replacement_guid,
      replacement_rv_info: rv_info,
      replacement_pub_key: pub_key,
      replacement_hmac: hmac
    ]

    update_session(realm_name, guid, updates)
  end

  defp update_session(realm_name, guid, updates) do
    keyspace = Realm.keyspace_name(realm_name)
    consistency = Consistency.device_info(:write)
    opts = [prefix: keyspace, consistency: consistency]

    %TO2Session{guid: guid}
    |> Ecto.Changeset.change(updates)
    |> Repo.update(opts)
    |> case do
      {:ok, _} -> :ok
      _ -> {:error, :session_not_found}
    end
  end

  def fetch_session(realm_name, guid) do
    keyspace = Realm.keyspace_name(realm_name)
    consistency = Consistency.device_info(:read)
    opts = [prefix: keyspace, consistency: consistency]
    Repo.fetch(TO2Session, guid, opts)
  end
end
