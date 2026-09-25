#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.DataAccess.FDO.Queries do
  @moduledoc """
  This module is responsible for the interaction with the database.
  """

  import Ecto.Query

  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.FDO.OwnershipVoucher
  alias Astarte.DataAccess.FDO.TO2Session
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  require Logger

  def fetch_ownership_voucher(guid) do
    keyspace_name = Realm.astarte_keyspace_name()
    opts = [consistency: Consistency.domain_model(:read), prefix: keyspace_name]

    Repo.fetch(OwnershipVoucher, guid, opts)
  end

  def fetch_device_id_and_ownership_voucher_and_realm(guid) do
    keyspace_name = Realm.astarte_keyspace_name()

    query =
      from o in OwnershipVoucher,
        prefix: ^keyspace_name,
        select: {o.realm, o.device_id, o.voucher_data}

    consistency = Consistency.domain_model(:read)

    Repo.fetch(query, guid, consistency: consistency)
  end

  def list_ownership_vouchers(realm_name) do
    keyspace_name = Realm.astarte_keyspace_name()

    query =
      from o in OwnershipVoucher,
        hints: ["ALLOW FILTERING"],
        prefix: ^keyspace_name,
        where: o.realm == ^realm_name

    consistency = Consistency.domain_model(:read)

    Repo.fetch_all(query, consistency: consistency)
  end

  def get_owner_key_params(guid) do
    keyspace_name = Realm.astarte_keyspace_name()

    query =
      from OwnershipVoucher,
        prefix: ^keyspace_name,
        select: [:key_name, :key_algorithm]

    consistency = Consistency.domain_model(:read)

    with {:ok, ov} <- Repo.fetch(query, guid, consistency: consistency) do
      result = %{name: ov.key_name, algorithm: ov.key_algorithm}
      {:ok, result}
    end
  end

  def get_replacement_data(guid) do
    keyspace = Realm.astarte_keyspace_name()

    fields = [:replacement_guid, :replacement_rendezvous_info, :replacement_public_key]

    query =
      from OwnershipVoucher,
        prefix: ^keyspace,
        select: ^fields

    consistency = Consistency.domain_model(:read)
    opts = [consistency: consistency]

    with {:ok, data} <- Repo.fetch(query, guid, opts) do
      result = Map.take(data, fields)
      {:ok, result}
    end
  end

  @spec create_ownership_voucher(OwnershipVoucher.t()) :: :ok | {:error, term()}
  def create_ownership_voucher(ownership_voucher) do
    keyspace_name = Realm.astarte_keyspace_name()

    # explicitly prevent updates to an already existing entry for the same GUID;
    # expect a "stale entry error" if no rows were changed due to GUID already present
    opts = [
      prefix: keyspace_name,
      consistency: Consistency.device_info(:write),
      overwrite: false,
      stale_error_field: :guid
    ]

    case Repo.insert(ownership_voucher, opts) do
      {:ok, _} ->
        :ok

      {:error, %Ecto.Changeset{errors: [guid: {_, [stale: true]}]}} ->
        {:error, :duplicated_voucher_guid}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  def delete_ownership_voucher(guid) do
    keyspace = Realm.astarte_keyspace_name()
    consistency = Consistency.device_info(:write)
    opts = [prefix: keyspace, consistency: consistency]

    %OwnershipVoucher{
      guid: guid
    }
    |> Repo.delete(opts)
    |> case do
      {:ok, _voucher} -> :ok
      error -> error
    end
  end

  @doc """
  Marks an ownership voucher as claimed by its device.

  The registration made on the rendezvous server during TO0 is consumed by TO2,
  so the expiry is cleared along with the status change.
  """
  def mark_voucher_as_claimed(guid) do
    keyspace = Realm.astarte_keyspace_name()
    consistency = Consistency.device_info(:write)
    opts = [prefix: keyspace, consistency: consistency]

    result =
      %OwnershipVoucher{guid: guid}
      |> Ecto.Changeset.change(status: :claimed)
      # `change/2` skips values that already match the (empty) struct, so the
      # expiry has to be forced in to actually be written as null
      |> Ecto.Changeset.force_change(:expiry, nil)
      |> Repo.update(opts)

    with {:ok, _} <- result, do: :ok
  end

  def update_voucher_expiry(guid, expiry) do
    keyspace = Realm.astarte_keyspace_name()
    consistency = Consistency.device_info(:write)
    opts = [prefix: keyspace, consistency: consistency]

    result =
      %OwnershipVoucher{guid: guid}
      |> Ecto.Changeset.change(expiry: expiry)
      |> Repo.update(opts)

    with {:ok, _} <- result, do: :ok
  end

  def add_output_voucher(
        guid,
        new_voucher
      ) do
    keyspace = Realm.astarte_keyspace_name()
    consistency = Consistency.device_info(:write)
    opts = [prefix: keyspace, consistency: consistency]

    result =
      %OwnershipVoucher{guid: guid}
      |> Ecto.Changeset.change(output_voucher: new_voucher)
      |> Repo.update(opts)

    with {:ok, _} <- result, do: :ok
  end

  def store_session(session) do
    keyspace = Realm.astarte_keyspace_name()
    consistency = Consistency.device_info(:write)
    opts = [prefix: keyspace, consistency: consistency]

    with {:ok, _} <- Repo.insert(session, opts) do
      :ok
    end
  end

  def delete_session(guid) do
    keyspace = Realm.astarte_keyspace_name()
    consistency = Consistency.device_info(:write)
    opts = [prefix: keyspace, consistency: consistency]

    Repo.delete(%TO2Session{guid: guid}, opts)
    :ok
  end

  def add_session_max_owner_service_info_size(guid, size) do
    updates = [max_owner_service_info_size: size]
    update_session(guid, updates)
  end

  def add_session_secret(guid, secret) do
    updates = [secret: secret]
    update_session(guid, updates)
  end

  def add_session_keys(guid, sevk, svk, sek) do
    updates = [sevk: sevk, svk: svk, sek: sek]
    update_session(guid, updates)
  end

  def session_add_setup_dv_nonce(guid, setup_dv_nonce) do
    updates = [setup_dv_nonce: setup_dv_nonce]
    update_session(guid, updates)
  end

  def session_update_device_id(guid, device_id) do
    updates = [device_id: device_id]
    update_session(guid, updates)
  end

  def session_add_device_service_info(guid, service_info) do
    updates = [device_service_info: service_info]
    update_session(guid, updates)
  end

  def session_add_owner_service_info(guid, owner_service_info) do
    updates = [owner_service_info: owner_service_info]
    update_session(guid, updates)
  end

  def session_update_last_chunk_sent(guid, last_chunk) do
    updates = [last_chunk_sent: last_chunk]
    update_session(guid, updates)
  end

  def session_add_replacement_hmac(guid, hmac) do
    updates = [replacement_hmac: hmac]
    update_session(guid, updates)
  end

  defp update_session(guid, updates) do
    keyspace = Realm.astarte_keyspace_name()
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

  def fetch_session(guid) do
    keyspace = Realm.astarte_keyspace_name()
    consistency = Consistency.device_info(:read)
    opts = [prefix: keyspace, consistency: consistency]
    Repo.fetch(TO2Session, guid, opts)
  end
end
