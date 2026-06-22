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
  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Device, as: DeviceCore
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.Mapping
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.Device.InsertContext
  alias Astarte.DataAccess.Device.UnconfirmedDevice
  alias Astarte.DataAccess.Devices.Device
  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo

  import Ecto.Query

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
    unconfirmed? = Keyword.get(opts, :unconfirmed, false)
    opts = [prefix: keyspace_name, consistency: consistency]

    with :ok <- register_unconfirmed_device(unconfirmed?, device_id, opts) do
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
    unconfirmed? = Keyword.get(opts, :unconfirmed, false)
    opts = [prefix: keyspace_name, consistency: consistency]

    with :ok <- register_unconfirmed_device(unconfirmed?, device.device_id, opts) do
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

  defp register_unconfirmed_device(false, _device_id, _opts), do: :ok

  defp register_unconfirmed_device(true, device_id, opts) do
    opts =
      opts
      |> Keyword.put(:overwrite, false)
      |> Keyword.put(:allow_stale, true)

    result =
      %UnconfirmedDevice{device_id: device_id, created_at: DateTime.utc_now()}
      |> Repo.insert(opts)

    with {:ok, _} <- result do
      :ok
    end
  end

  @spec confirm(String.t(), DeviceCore.device_id()) ::
          {:ok, Device.t()} | {:error, :device_not_found}
  def confirm(realm_name, device_id) do
    unconfirmed_device = %UnconfirmedDevice{device_id: device_id}
    keyspace = Realm.keyspace_name(realm_name)
    delete_opts = [prefix: keyspace, consistency: Consistency.device_info(:write)]

    fetch_opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:read),
      error: :device_not_found
    ]

    Repo.delete!(unconfirmed_device, delete_opts)
    Repo.fetch(Device, device_id, fetch_opts)
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

  def insert_value_into_db(
        %{
          interface_descriptor: %InterfaceDescriptor{
            storage_type: :multi_interface_individual_properties_dbtable
          },
          mapping: %Mapping{allow_unset: true},
          value: nil
        } = context
      ) do
    %InsertContext{
      realm: realm,
      device_id: device_id,
      interface_descriptor: interface_descriptor,
      mapping: mapping,
      path: path,
      opts: opts
    } = context

    %InterfaceDescriptor{storage: storage, interface_id: interface_id} = interface_descriptor
    %Mapping{endpoint_id: endpoint_id} = mapping
    keyspace = Realm.keyspace_name(realm)

    _ =
      remove_property_row(keyspace, storage, device_id, interface_id, endpoint_id, path, opts)

    :ok
  end

  def insert_value_into_db(
        %{
          interface_descriptor: %InterfaceDescriptor{
            storage_type: :multi_interface_individual_properties_dbtable
          },
          value: nil
        } = context
      ) do
    %InsertContext{
      realm: realm,
      device_id: device_id
    } = context

    _ =
      Logger.warning(
        "Device #{inspect(device_id)} in realm #{realm} tried to unset an unsettable property.",
        tag: :unset_not_allowed
      )

    {:error, :unset_not_allowed}
  end

  def insert_value_into_db(
        %{
          interface_descriptor: %InterfaceDescriptor{
            storage_type: :multi_interface_individual_properties_dbtable
          }
        } = context
      ) do
    %InsertContext{
      realm: realm,
      device_id: device_id,
      interface_descriptor: interface_descriptor,
      mapping: mapping,
      path: path,
      value: value,
      reception_timestamp: reception_timestamp,
      encrypted_dek: encrypted_dek
    } = context

    %InterfaceDescriptor{interface_id: interface_id, storage: storage} = interface_descriptor
    %Mapping{endpoint_id: endpoint_id, value_type: value_type, encrypted: encrypted} = mapping
    keyspace_name = Realm.keyspace_name(realm)
    timestamp = div(reception_timestamp, 10_000)
    reception_timestamp_submillis = rem(reception_timestamp, 10_000)

    column_name =
      case encrypted do
        true -> "encryptedblob_value"
        _ -> CQLUtils.type_to_db_column_name(value_type)
      end

    db_value = to_db_friendly_type(value)

    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_value = %{
      "device_id" => device_id,
      "interface_id" => interface_id,
      "endpoint_id" => endpoint_id,
      "path" => path,
      "reception_timestamp" => timestamp,
      "reception_timestamp_submillis" => reception_timestamp_submillis,
      "encrypted_dek" => encrypted_dek,
      column_name => db_value
    }

    insert_opts = [
      prefix: keyspace_name,
      consistency: Consistency.device_info(:write)
    ]

    _ = Repo.insert_all(storage, [insert_value], insert_opts)
    :ok
  end

  def insert_value_into_db(
        %{
          interface_descriptor: %InterfaceDescriptor{
            storage_type: :multi_interface_individual_datastream_dbtable
          }
        } = context
      ) do
    %InsertContext{
      realm: realm,
      device_id: device_id,
      interface_descriptor: interface_descriptor,
      mapping: mapping,
      path: path,
      value: value,
      value_timestamp: value_timestamp,
      reception_timestamp: reception_timestamp,
      encrypted_dek: encrypted_dek,
      opts: opts
    } = context

    %InterfaceDescriptor{interface_id: interface_id, storage: storage} = interface_descriptor
    %Mapping{endpoint_id: endpoint_id, value_type: value_type, encrypted: encrypted} = mapping
    keyspace_name = Realm.keyspace_name(realm)
    timestamp = div(reception_timestamp, 10_000)
    reception_timestamp_submillis = rem(reception_timestamp, 10_000)

    column_name =
      case encrypted do
        true -> "encryptedblob_value"
        _ -> CQLUtils.type_to_db_column_name(value_type)
      end

    db_value = to_db_friendly_type(value)

    # TODO: use received value_timestamp when needed
    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_value = %{
      "device_id" => device_id,
      "interface_id" => interface_id,
      "endpoint_id" => endpoint_id,
      "path" => path,
      "value_timestamp" => value_timestamp,
      "reception_timestamp" => timestamp,
      "reception_timestamp_submillis" => reception_timestamp_submillis,
      "encrypted_dek" => encrypted_dek,
      column_name => db_value
    }

    insert_opts = [
      prefix: keyspace_name,
      consistency: Consistency.time_series(:write, mapping)
    ]

    _ = Repo.insert_all(storage, [insert_value], Keyword.merge(opts, insert_opts))

    :ok
  end

  def insert_value_into_db(
        %{
          interface_descriptor: %InterfaceDescriptor{storage_type: :one_object_datastream_dbtable}
        } = context
      ) do
    %InsertContext{
      realm: realm,
      device_id: device_id,
      interface_descriptor: interface_descriptor,
      mapping: mapping,
      path: path,
      value: value,
      value_timestamp: value_timestamp,
      reception_timestamp: reception_timestamp,
      encrypted_endpoints: encrypted_endpoints,
      encrypted_dek: encrypted_dek,
      opts: opts
    } = context

    %InterfaceDescriptor{interface_id: interface_id, storage: storage} = interface_descriptor

    keyspace_name = Realm.keyspace_name(realm)
    timestamp = div(reception_timestamp, 10_000)
    reception_timestamp_submillis = rem(reception_timestamp, 10_000)

    # TODO: we should cache endpoints by interface_id
    column_info =
      Endpoint
      |> select([:endpoint, :value_type])
      |> where(interface_id: ^interface_id)
      |> put_query_prefix(keyspace_name)
      |> Repo.all(consistency: Consistency.domain_model(:read))
      |> Map.new(fn endpoint ->
        value_name = endpoint.endpoint |> String.split("/") |> List.last()
        column_name = CQLUtils.endpoint_to_db_column_name(value_name)
        {value_name, column_name}
      end)

    # TODO: we should also cache explicit_timestamp
    explicit_timestamp_query =
      from e in Endpoint,
        prefix: ^keyspace_name,
        where: e.interface_id == ^interface_id,
        select: e.explicit_timestamp,
        limit: 1

    [explicit_timestamp?] =
      Repo.all(explicit_timestamp_query, consistency: Consistency.domain_model(:read))

    # TODO: use received value_timestamp when needed
    # TODO: :reception_timestamp_submillis is just a place holder right now
    insert_params = %{
      "device_id" => device_id,
      "path" => path,
      "reception_timestamp" => timestamp,
      "reception_timestamp_submillis" => reception_timestamp_submillis
    }

    object_value =
      compute_db_object_entries(column_info, value)
      |> maybe_add_dek_to_object(encrypted_endpoints, encrypted_dek)

    insert_value = Map.merge(insert_params, object_value)

    insert_value =
      if explicit_timestamp? do
        Map.put(insert_value, "value_timestamp", value_timestamp)
      else
        insert_value
      end

    insert_opts = [
      prefix: keyspace_name,
      consistency: Consistency.time_series(:write, mapping)
    ]

    _ = Repo.insert_all(storage, [insert_value], Keyword.merge(opts, insert_opts))

    :ok
  end

  defp remove_property_row(
         keyspace,
         table,
         device_id,
         interface_id,
         endpoint_id,
         path,
         opts
       ) do
    query =
      from table,
        prefix: ^keyspace,
        where: [
          device_id: ^device_id,
          interface_id: ^interface_id,
          endpoint_id: ^endpoint_id,
          path: ^path
        ]

    opts = Keyword.merge(opts, consistency: Consistency.device_info(:write))

    _ = Repo.delete_all(query, opts)
  end

  # add a column to contain the DEK if at least one endpoint of the object is encrypted
  defp maybe_add_dek_to_object(object, [], _) do
    object
  end

  defp maybe_add_dek_to_object(object, _endpoints, dek) do
    Map.put(object, "encrypted_dek", dek)
  end

  defp compute_db_object_entries(column_info, object) do
    Enum.reduce(object, %{}, fn {object_key, object_value}, acc ->
      case Map.fetch(column_info, object_key) do
        {:ok, column_name} ->
          db_value = to_db_friendly_type(object_value)
          Map.put(acc, column_name, db_value)

        :error ->
          _ =
            Logger.warning(
              "Unexpected object key #{object_key} with value #{inspect(object_value)}."
            )

          acc
      end
    end)
  end

  defp to_db_friendly_type(array) when is_list(array) do
    # If we have an array, we convert its elements to a db friendly type
    Enum.map(array, &to_db_friendly_type/1)
  end

  defp to_db_friendly_type(%DateTime{} = datetime) do
    DateTime.to_unix(datetime, :millisecond)
  end

  # From Cyanide 2.0, binaries are decoded as %Cyanide.Binary{}
  defp to_db_friendly_type(%Cyanide.Binary{subtype: _subtype, data: bin}) do
    bin
  end

  defp to_db_friendly_type(value) do
    value
  end
end
