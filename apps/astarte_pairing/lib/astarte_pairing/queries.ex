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

  def check_already_registered_device(realm_name, device_id) do
    keyspace_name = Realm.keyspace_name(realm_name)

    consistency = Consistency.device_info(:read)

    case Repo.get(Device, device_id, prefix: keyspace_name, consistency: consistency) do
      %Device{} -> true
      nil -> false
    end
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
end
