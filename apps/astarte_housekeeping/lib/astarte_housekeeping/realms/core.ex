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

defmodule Astarte.Housekeeping.Realms.Core do
  @moduledoc false
  alias Astarte.Housekeeping.Realms.Queries
  alias Astarte.Housekeeping.Realms.Realm

  require Logger

  def update_realm(realm_name, changes) do
    Logger.info("Updating realm #{realm_name}", tag: "realm_update_start")

    with {:ok, realm} <- Queries.get_realm(realm_name) do
      updated_realm =
        Enum.reduce(changes, realm, fn {field, changed_value}, acc_realm ->
          case update_realm_field(acc_realm, field, changed_value) do
            :ok -> %{acc_realm | field => changed_value}
            {:ok, realm} -> realm
          end
        end)

      {:ok, updated_realm}
    end
  end

  defp update_realm_field(realm, :jwt_public_key_pem, jwt_public_key_pem) do
    Queries.update_public_key(realm.realm_name, jwt_public_key_pem)
  end

  defp update_realm_field(realm, :device_registration_limit, :unset) do
    Logger.info("Removing device registration limit", tag: "remove_device_registration_limit")
    Queries.delete_device_registration_limit(realm.realm_name)

    {:ok, %{realm | device_registration_limit: nil}}
  end

  defp update_realm_field(realm, :device_registration_limit, limit) when is_integer(limit) do
    Logger.info("Updating device registration limit", tag: "update_device_registration_limit")

    Queries.set_device_registration_limit(realm.realm_name, limit)
  end

  defp update_realm_field(realm, :datastream_maximum_storage_retention, :unset) do
    Logger.info("Removing datastream maximum storage retention",
      tag: "remove_datastream_maximum_storage_retention"
    )

    Queries.delete_datastream_maximum_storage_retention(realm.realm_name)

    {:ok, %{realm | datastream_maximum_storage_retention: nil}}
  end

  defp update_realm_field(realm, :datastream_maximum_storage_retention, retention)
       when is_integer(retention) do
    Logger.info("Updating datastream maximum storage retention",
      tag: "update_datastream_maximum_storage_retention"
    )

    Queries.set_datastream_maximum_storage_retention(realm.realm_name, retention)
  end

  def create_realm(
        %Realm{
          realm_name: realm_name,
          jwt_public_key_pem: pem,
          replication_class: "SimpleStrategy",
          replication_factor: replication_factor,
          device_registration_limit: device_registration_limit,
          datastream_maximum_storage_retention: datastream_maximum_storage_retention
        },
        opts
      ) do
    do_create_realm(
      realm_name,
      pem,
      replication_factor,
      device_registration_limit,
      datastream_maximum_storage_retention,
      opts
    )
  end

  def create_realm(
        %Realm{
          realm_name: realm_name,
          jwt_public_key_pem: pem,
          replication_class: "NetworkTopologyStrategy",
          datacenter_replication_factors: replication_factors_map,
          device_registration_limit: device_registration_limit,
          datastream_maximum_storage_retention: datastream_maximum_storage_retention
        },
        opts
      ) do
    datacenter_replication_factors_map = Enum.into(Enum.to_list(replication_factors_map), %{})

    do_create_realm(
      realm_name,
      pem,
      datacenter_replication_factors_map,
      device_registration_limit,
      datastream_maximum_storage_retention,
      opts
    )
  end

  defp do_create_realm(
         realm_name,
         pem,
         replication,
         device_registration_limit,
         datastream_maximum_storage_retention,
         opts
       ) do
    with :ok <- create_vhost(realm_name) do
      Queries.create_realm(
        realm_name,
        pem,
        replication,
        device_registration_limit,
        datastream_maximum_storage_retention,
        opts
      )
    end
  end

  defp create_vhost(realm_name) do
    case Astarte.Housekeeping.AMQP.Vhost.create_vhost(realm_name) do
      :ok -> :ok
      :error -> {:error, :vhost_creation_error}
    end
  end
end
