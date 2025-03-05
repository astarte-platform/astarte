#
# This file is part of Astarte.
#
# Copyright 2017-2018 Ispirata Srl
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

  alias Astarte.Core.CQLUtils
  alias Astarte.Pairing.Config
  alias Astarte.Pairing.Astarte.Realm
  alias Astarte.Pairing.Realms.Device
  alias Astarte.Pairing.Realms.KvStore
  alias Astarte.Pairing.Repo
  require Logger
  import Ecto.Query

  @keyspace_does_not_exist_regex ~r/Keyspace (.*) does not exist/

  def get_agent_public_key_pems(realm_name) do
    keyspace = CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    try do
      with {:ok, pem} <-
             KvStore.fetch_value("auth", "jwt_public_key_pem", :string,
               prefix: keyspace,
               consistency: :quorum,
               error: :public_key_not_found
             ) do
        {:ok, [pem]}
      end
    rescue
      err -> handle_xandra_error(err)
    end
  end

  defp handle_xandra_error(%Xandra.ConnectionError{} = error) do
    _ =
      Logger.warning("Database connection error #{Exception.message(error)}.",
        tag: "database_connection_error"
      )

    {:error, :database_connection_error}
  end

  defp handle_xandra_error(%Xandra.Error{} = error) do
    %Xandra.Error{message: message} = error

    case Regex.run(@keyspace_does_not_exist_regex, message) do
      [_message, keyspace] ->
        Logger.warning("Keyspace #{keyspace} does not exist.",
          tag: "realm_not_found"
        )

        {:error, :realm_not_found}

      nil ->
        _ =
          Logger.warning(
            "Database error: #{Exception.message(error)}.",
            tag: "database_error"
          )

        {:error, :database_error}
    end
  end

  def register_device(realm_name, device_id, extended_id, credentials_secret, opts \\ []) do
    case fetch_device(realm_name, device_id) do
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

          {:error, :already_registered}
        end

      {:error, reason} ->
        {:error, reason}
    end
  end

  def unregister_device(realm_name, device_id) do
    with {:ok, device} <- fetch_device(realm_name, device_id),
         {:ok, _device} <- do_unregister_device(realm_name, device) do
      :ok
    else
      {:error, reason} ->
        Logger.warning("Unregister error: #{inspect(reason)}")
        {:error, reason}
    end
  end

  def check_already_registered_device(realm_name, device_id) do
    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    case Repo.get(Device, device_id, prefix: keyspace_name, consistency: :quorum) do
      %Device{} -> true
      nil -> false
    end
  end

  defp do_unregister_device(realm_name, %Device{} = device) do
    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    device
    |> Ecto.Changeset.change(
      first_credentials_request: nil,
      credentials_secret: nil
    )
    |> Repo.update(prefix: keyspace_name, consistency: :quorum)
  end

  def fetch_device(realm_name, device_id) do
    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    try do
      Repo.fetch(Device, device_id,
        prefix: keyspace_name,
        consistency: :quorum,
        error: :device_not_found
      )
    rescue
      err -> handle_xandra_error(err)
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
    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    device
    |> Ecto.Changeset.change(%{
      cert_aki: aki,
      cert_serial: serial,
      last_credentials_request_ip: device_ip,
      first_credentials_request: first_credentials_request_timestamp
    })
    |> Repo.update(prefix: keyspace_name, consistency: :quorum)
  end

  def fetch_device_registration_limit(realm_name) do
    keyspace = CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())

    try do
      case Repo.fetch(Realm, realm_name,
             prefix: keyspace,
             consistency: :one,
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
    rescue
      err -> handle_xandra_error(err)
    end
  end

  def fetch_registered_devices_count(realm_name) do
    keyspace =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    try do
      count =
        Device
        |> select([d], count())
        |> Repo.one!(prefix: keyspace, consistency: :one)

      {:ok, count}
    rescue
      err -> handle_xandra_error(err)
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

    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    %Device{}
    |> Ecto.Changeset.change(%{
      device_id: device_id,
      first_registration: registration_timestamp,
      credentials_secret: credentials_secret,
      inhibit_credentials_request: false,
      protocol_revision: 0,
      total_received_bytes: 0,
      total_received_msgs: 0,
      introspection: introspection,
      introspection_minor: introspection_minor
    })
    |> Repo.insert(prefix: keyspace_name, consistency: :quorum)
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

    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    device
    |> Ecto.Changeset.change(%{
      credentials_secret: credentials_secret,
      inhibit_credentials_request: false,
      protocol_revision: 0,
      introspection: introspection,
      introspection_minor: introspection_minor
    })
    |> Repo.update(prefix: keyspace_name, consistency: :quorum)
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

  def check_astarte_health(consistency) do
    query = """
    SELECT COUNT(*)
    FROM #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms
    """

    with {:ok, %Xandra.Page{} = page} <-
           Xandra.Cluster.execute(:xandra, query, %{}, consistency: consistency),
         {:ok, _} <- Enum.fetch(page, 0) do
      :ok
    else
      :error ->
        _ =
          Logger.warning("Cannot retrieve count for astarte.realms table.",
            tag: "health_check_error"
          )

        {:error, :health_check_bad}

      {:error, %Xandra.Error{} = err} ->
        _ =
          Logger.warning("Database error, health is not good: #{inspect(err)}.",
            tag: "health_check_database_error"
          )

        {:error, :health_check_bad}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database error, health is not good: #{inspect(err)}.",
            tag: "health_check_database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end
end
