#
# This file is part of Astarte.
#
# Copyright 2018 - 2025 SECO Mind Srl
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

defmodule Astarte.DataAccess.Device do
  @moduledoc """
  This module provides functions to fetch and manipulate device information in Astarte Data Access.
  """
  require Logger
  alias Astarte.Core.Device, as: DeviceCore
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Ecto.Changeset

  import Ecto.Query

  @ten_minutes_in_seconds 600

  @spec interface_version(String.t(), DeviceCore.device_id(), String.t()) ::
          {:ok, integer} | {:error, atom}
  def interface_version(realm, device_id, interface_name) do
    keyspace = Realm.keyspace_name(realm)
    consistency = Consistency.device_info(:read)

    device_fetch =
      Device
      |> where(device_id: ^device_id)
      |> select([:introspection])
      |> Repo.fetch_one(error: :device_not_found, prefix: keyspace, consistency: consistency)

    with {:ok, device} <- device_fetch do
      retrieve_major(device, interface_name)
    end
  end

  defp retrieve_major(%{introspection: introspection}, interface_name) do
    case introspection do
      %{^interface_name => major} -> {:ok, major}
      _ -> {:error, :interface_not_in_introspection}
    end
  end

  defp retrieve_major(nil, _) do
    {:error, :device_not_found}
  end

  @spec add_unconfirmed_credentials(String.t(), DeviceCore.device_id(), String.t()) ::
          :ok | {:error, term()}
  def add_unconfirmed_credentials(realm_name, device_id, credentials_secret) do
    opts = [
      prefix: Realm.keyspace_name(realm_name),
      consistency: Consistency.device_info(:write),
      ttl: @ten_minutes_in_seconds,
      allow_insert: false,
      allow_stale: true
    ]

    device_result =
      %Device{device_id: device_id}
      |> Changeset.change(%{
        credentials_secret: credentials_secret
      })
      |> Repo.update(opts)

    with {:ok, _} <- device_result do
      :ok
    end
  end

  def register(realm_name, device_id, extended_id, credentials_secret, opts \\ []) do
    case fetch(realm_name, device_id) do
      {:error, :device_not_found} ->
        Logger.info("register request for new device: #{inspect(extended_id)}")

        registration_timestamp = DateTime.utc_now()

        do_register_device(
          realm_name,
          device_id,
          credentials_secret,
          registration_timestamp,
          opts
        )

      {:ok, device} ->
        if is_nil(device.first_credentials_request) do
          Logger.info("register request for existing unconfirmed device: #{inspect(extended_id)}")

          do_register_unconfirmed_device(
            realm_name,
            device,
            credentials_secret,
            opts
          )
        else
          Logger.warning(
            "register request for existing confirmed device: #{inspect(extended_id)}"
          )

          {:error, :device_already_registered}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp do_register_device(
         realm_name,
         device_id,
         credentials_secret,
         %DateTime{} = registration_timestamp,
         opts
       ) do
    {introspection, introspection_minor} =
      opts
      |> Keyword.get(:initial_introspection, [])
      |> build_initial_introspection_maps()

    keyspace_name = Realm.keyspace_name(realm_name)
    consistency = Consistency.device_info(:write)
    opts = [prefix: keyspace_name, consistency: consistency]

    %Device{
      device_id: device_id,
      first_registration: registration_timestamp,
      credentials_secret: credentials_secret,
      inhibit_credentials_request: false,
      protocol_revision: 0,
      total_received_bytes: 0,
      total_received_msgs: 0,
      introspection: introspection,
      introspection_minor: introspection_minor
    }
    |> Repo.insert(opts)
  end

  defp do_register_unconfirmed_device(
         realm_name,
         %Device{} = device,
         credentials_secret,
         opts
       ) do
    {introspection, introspection_minor} =
      opts
      |> Keyword.get(:initial_introspection, [])
      |> build_initial_introspection_maps()

    keyspace_name = Realm.keyspace_name(realm_name)
    consistency = Consistency.device_info(:write)
    opts = [prefix: keyspace_name, consistency: consistency]

    device
    |> Ecto.Changeset.change(%{
      credentials_secret: credentials_secret,
      inhibit_credentials_request: false,
      protocol_revision: 0,
      introspection: introspection,
      introspection_minor: introspection_minor
    })
    |> Repo.insert(opts)
  end

  defp build_initial_introspection_maps(initial_introspection) do
    Enum.reduce(initial_introspection, {[], []}, fn introspection_entry, {majors, minors} ->
      %{
        interface_name: interface_name,
        major_version: major_version,
        minor_version: minor_version
      } = introspection_entry

      {[{interface_name, major_version} | majors], [{interface_name, minor_version} | minors]}
    end)
  end

  @spec confirm(String.t(), DeviceCore.device_id()) ::
          {:ok, Device.t()} | {:error, :device_not_found} | {:error, :expired_credentials}
  def confirm(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)

    insert_opts = [prefix: keyspace, consistency: Consistency.device_info(:write)]

    fetch_opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:read),
      error: :device_not_found
    ]

    with {:ok, device} <- Repo.fetch(Device, device_id, fetch_opts),
         :ok <- check_not_expired_credentials(device) do
      # Removes TTL from credentials_secret
      Repo.insert(device, insert_opts)
    end
  end

  defp check_not_expired_credentials(device) do
    case device.credentials_secret do
      nil -> {:error, :expired_credentials}
      _ -> :ok
    end
  end

  def fetch(realm_name, device_id) do
    keyspace_name = Realm.keyspace_name(realm_name)

    consistency = Consistency.device_info(:read)

    Repo.fetch(Device, device_id,
      prefix: keyspace_name,
      consistency: consistency,
      error: :device_not_found
    )
  end

  def fetch_with_unconfirmed_status(realm_name, device_id) do
    keyspace_name = Realm.keyspace_name(realm_name)

    opts = [
      prefix: keyspace_name,
      consistency: Consistency.device_info(:read),
      error: :device_not_found
    ]

    device_query =
      from d in Device,
        select: %{
          device_id: d.device_id,
          aliases: d.aliases,
          attributes: d.attributes,
          cert_aki: d.cert_aki,
          cert_serial: d.cert_serial,
          connected: d.connected,
          credentials_secret: d.credentials_secret,
          exchanged_bytes_by_interface: d.exchanged_bytes_by_interface,
          exchanged_msgs_by_interface: d.exchanged_msgs_by_interface,
          first_credentials_request: d.first_credentials_request,
          first_registration: d.first_registration,
          groups: d.groups,
          inhibit_credentials_request: d.inhibit_credentials_request,
          introspection: d.introspection,
          introspection_minor: d.introspection_minor,
          last_connection: d.last_connection,
          last_credentials_request_ip: d.last_credentials_request_ip,
          last_disconnection: d.last_disconnection,
          last_seen_ip: d.last_seen_ip,
          old_introspection: d.old_introspection,
          capabilities: d.capabilities,
          pending_empty_cache: d.pending_empty_cache,
          protocol_revision: d.protocol_revision,
          total_received_bytes: d.total_received_bytes,
          total_received_msgs: d.total_received_msgs,
          credentials_secret_ttl: fragment("TTL(?)", d.credentials_secret)
        }

    with {:ok, device_params} <- Repo.fetch(device_query, device_id, opts) do
      %{
        device_id: device_id,
        aliases: aliases,
        attributes: attributes,
        cert_aki: cert_aki,
        cert_serial: cert_serial,
        connected: connected,
        credentials_secret: credentials_secret,
        exchanged_bytes_by_interface: exchanged_bytes_by_interface,
        exchanged_msgs_by_interface: exchanged_msgs_by_interface,
        first_credentials_request: first_credentials_request,
        first_registration: first_registration,
        groups: groups,
        inhibit_credentials_request: inhibit_credentials_request,
        introspection: introspection,
        introspection_minor: introspection_minor,
        last_connection: last_connection,
        last_credentials_request_ip: last_credentials_request_ip,
        last_disconnection: last_disconnection,
        last_seen_ip: last_seen_ip,
        old_introspection: old_introspection,
        capabilities: capabilities,
        pending_empty_cache: pending_empty_cache,
        protocol_revision: protocol_revision,
        total_received_bytes: total_received_bytes,
        total_received_msgs: total_received_msgs,
        credentials_secret_ttl: credentials_secret_ttl
      } = device_params

      confirmation_status =
        case credentials_secret_ttl do
          nil -> :confirmed
          _ -> :unconfirmed
        end

      device =
        %Device{
          device_id: device_id,
          aliases: aliases,
          attributes: attributes,
          cert_aki: cert_aki,
          cert_serial: cert_serial,
          connected: connected,
          credentials_secret: credentials_secret,
          exchanged_bytes_by_interface: exchanged_bytes_by_interface,
          exchanged_msgs_by_interface: exchanged_msgs_by_interface,
          first_credentials_request: first_credentials_request,
          first_registration: first_registration,
          groups: groups,
          inhibit_credentials_request: inhibit_credentials_request,
          introspection: introspection,
          introspection_minor: introspection_minor,
          last_connection: last_connection,
          last_credentials_request_ip: last_credentials_request_ip,
          last_disconnection: last_disconnection,
          last_seen_ip: last_seen_ip,
          old_introspection: old_introspection,
          capabilities: capabilities,
          pending_empty_cache: pending_empty_cache,
          protocol_revision: protocol_revision,
          total_received_bytes: total_received_bytes,
          total_received_msgs: total_received_msgs,
          confirmation_status: confirmation_status
        }

      {:ok, device}
    end
  end

  def unregister(realm_name, device_id) do
    with {:ok, device} <- fetch(realm_name, device_id),
         {:ok, _device} <- do_unregister_device(realm_name, device) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("Unregister error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp do_unregister_device(realm_name, %Device{} = device) do
    keyspace_name = Realm.keyspace_name(realm_name)

    consistency = Consistency.device_info(:write)

    device
    |> Changeset.change(
      first_credentials_request: nil,
      credentials_secret: nil
    )
    |> Repo.update(prefix: keyspace_name, consistency: consistency)
  end
end
