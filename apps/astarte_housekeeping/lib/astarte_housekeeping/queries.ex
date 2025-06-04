#
# This file is part of Astarte.
#
# Copyright 2017-2023 SECO Mind Srl
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

defmodule Astarte.Housekeeping.Queries do
  require Logger
  alias Astarte.Core.CQLUtils
  alias Astarte.Housekeeping.Config
  alias Astarte.Housekeeping.Migrator
  alias Astarte.DataAccess.XandraUtils
  alias Astarte.DataAccess.Realm

  def check_astarte_health(consistency) do
    case XandraUtils.run_without_realm_validation("astarte", fn conn, keyspace_name ->
           do_check_astarte_health(conn, keyspace_name, consistency)
         end) do
      {:ok, result} ->
        result

      {:error, %Xandra.Error{} = err} ->
        _ =
          Logger.warning("Database error, health is not good: #{inspect(err)}.",
            tag: "health_check_database_error"
          )

        {:error, :health_check_bad}
    end
  end

  defp do_check_astarte_health(conn, astarte_keyspace_name, consistency) do
    query = """
    SELECT
      realm_name
    FROM
      #{astarte_keyspace_name}.realms
    """

    with {:ok, page} <- XandraUtils.retrieve_page(conn, query, consistency: consistency),
         {:ok, %{count: _count}} <- Enum.fetch(page, 0) do
      :ok
    else
      :error ->
        _ =
          Logger.warning(
            "Cannot retrieve count for #{astarte_keyspace_name}.realms table.",
            tag: "health_check_error"
          )

        {:error, :health_check_bad}
    end
  end

  def delete_device_registration_limit(realm_name) do
    with :ok <- XandraUtils.verify_realm_name(realm_name) do
      Xandra.Cluster.run(:xandra, fn conn ->
        do_delete_device_registration_limit(conn, realm_name)
      end)
    end
  end

  def set_device_registration_limit(realm_name, new_limit) do
    with :ok <- XandraUtils.verify_realm_name(realm_name) do
      Xandra.Cluster.run(:xandra, fn conn ->
        do_set_device_registration_limit(conn, realm_name, new_limit)
      end)
    end
  end

  defp build_replication_map_str(replication_factor)
       when is_integer(replication_factor) and replication_factor > 0 do
    replication_map_str =
      "{'class': 'SimpleStrategy', 'replication_factor': #{replication_factor}}"

    {:ok, replication_map_str}
  end

  defp build_replication_map_str(datacenter_replication_factors)
       when is_map(datacenter_replication_factors) do
    datacenter_replications_str =
      Enum.map(datacenter_replication_factors, fn {datacenter, replication_factor} ->
        "'#{datacenter}': #{replication_factor}"
      end)
      |> Enum.join(",")

    replication_map_str = "{'class': 'NetworkTopologyStrategy', #{datacenter_replications_str}}"

    {:ok, replication_map_str}
  end

  defp build_replication_map_str(_invalid_replication) do
    {:error, :invalid_replication}
  end

  def initialize_database do
    Xandra.Cluster.run(:xandra, [timeout: 60_000], fn conn ->
      with :ok <- create_astarte_keyspace(conn),
           :ok <- create_realms_table(conn),
           :ok <- create_astarte_kv_store(conn),
           :ok <- insert_astarte_schema_version(conn) do
        :ok
      else
        {:error, %Xandra.Error{} = err} ->
          _ =
            Logger.error(
              "Database error while initializing database: #{inspect(err)}. ASTARTE WILL NOT WORK.",
              tag: "init_database_error"
            )

          {:error, :database_error}

        {:error, %Xandra.ConnectionError{} = err} ->
          _ =
            Logger.error(
              "Database connection error while initializing database: #{inspect(err)}. ASTARTE WILL NOT WORK.",
              tag: "init_database_connection_error"
            )

          {:error, :database_connection_error}

        {:error, reason} ->
          _ =
            Logger.error(
              "Error while initializing database: #{inspect(reason)}. ASTARTE WILL NOT WORK.",
              tag: "init_error"
            )

          {:error, reason}
      end
    end)
  end

  defp create_astarte_keyspace(conn) do
    # TODO: add support for creating the astarte keyspace with NetworkTopologyStrategy,
    # right now the replication factor is an integer so SimpleStrategy is always used
    astarte_keyspace_replication = Config.astarte_keyspace_replication_factor!()

    with {:ok, replication_map_str} <- build_replication_map_str(astarte_keyspace_replication),
         query = """
         CREATE KEYSPACE #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}
         WITH replication = #{replication_map_str}
         AND durable_writes = true;
         """,
         :ok <- Realm.check_replication(conn, astarte_keyspace_replication),
         {:ok, %Xandra.SchemaChange{}} <-
           Xandra.execute(conn, query, %{}, consistency: :each_quorum) do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}

      {:error, reason} ->
        _ =
          Logger.warning("Cannot create Astarte Keyspace: #{inspect(reason)}.",
            tag: "astarte_keyspace_creation_failed"
          )

        {:error, reason}
    end
  end

  defp create_realms_table(conn) do
    query = """
    CREATE TABLE #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms (
      realm_name varchar,
      device_registration_limit bigint,
      PRIMARY KEY (realm_name)
    );
    """

    with {:ok, %Xandra.SchemaChange{}} <-
           Xandra.execute(conn, query, %{}, consistency: :each_quorum) do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp create_astarte_kv_store(conn) do
    query = """
    CREATE TABLE #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.kv_store (
      group varchar,
      key varchar,
      value blob,

      PRIMARY KEY ((group), key)
    );
    """

    with {:ok, %Xandra.SchemaChange{}} <-
           Xandra.execute(conn, query, %{}, consistency: :each_quorum) do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp insert_astarte_schema_version(conn) do
    query = """
    INSERT INTO #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.kv_store
    (group, key, value)
    VALUES ('astarte', 'schema_version', bigintAsBlob(#{Migrator.latest_astarte_schema_version()}));
    """

    with {:ok, %Xandra.Void{}} <- Xandra.execute(conn, query, %{}, consistency: :each_quorum) do
      :ok
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warning("Database error: #{inspect(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{inspect(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  def set_datastream_maximum_storage_retention(realm_name, new_retention) do
    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    with :ok <- XandraUtils.verify_realm_name(realm_name) do
      Xandra.Cluster.run(
        :xandra,
        &do_set_datastream_maximum_storage_retention(&1, keyspace_name, new_retention)
      )
    end
  end

  def delete_datastream_maximum_storage_retention(realm_name) do
    keyspace_name =
      CQLUtils.realm_name_to_keyspace_name(realm_name, Config.astarte_instance_id!())

    with :ok <- XandraUtils.verify_realm_name(realm_name) do
      Xandra.Cluster.run(
        :xandra,
        &do_delete_datastream_maximum_storage_retention(&1, keyspace_name)
      )
    end
  end

  defp do_set_device_registration_limit(conn, realm_name, new_device_registration_limit) do
    statement = """
    UPDATE #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms
    SET device_registration_limit = :new_device_registration_limit
    WHERE realm_name = :realm_name
    """

    params = %{
      "new_device_registration_limit" => new_device_registration_limit,
      "realm_name" => realm_name
    }

    with {:ok, prepared} <- Xandra.prepare(conn, statement) do
      case Xandra.execute(conn, prepared, params, consistency: :quorum) do
        {:ok, result} ->
          {:ok, result}

        {:error, %Xandra.Error{} = err} ->
          _ = Logger.warning("Database error: #{Exception.message(err)}.", tag: "database_error")
          {:error, :database_error}

        {:error, %Xandra.ConnectionError{} = err} ->
          _ =
            Logger.warning("Database connection error: #{Exception.message(err)}.",
              tag: "database_connection_error"
            )

          {:error, :database_connection_error}
      end
    end
  end

  defp do_set_datastream_maximum_storage_retention(conn, realm_name, new_retention) do
    statement = """
    UPDATE :realm_name.kv_store
    SET value = intAsBlob(:new_retention)
    WHERE group='realm_config' AND key='datastream_maximum_storage_retention'
    """

    params = %{
      "new_retention" => new_retention
    }

    # TODO move away from this when NoaccOS' PR is merged
    query = String.replace(statement, ":realm_name", realm_name)

    # TODO refactor when NoaccOS' PR is merged
    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, result} <- Xandra.execute(conn, prepared, params, consistency: :quorum) do
      {:ok, result}
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warning("Database error: #{Exception.message(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{Exception.message(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end

  defp do_delete_device_registration_limit(conn, realm_name) do
    statement = """
    DELETE device_registration_limit
    FROM  #{CQLUtils.realm_name_to_keyspace_name("astarte", Config.astarte_instance_id!())}.realms
    WHERE realm_name = :realm_name
    """

    params = %{
      "realm_name" => realm_name
    }

    with {:ok, prepared} <- Xandra.prepare(conn, statement) do
      case Xandra.execute(conn, prepared, params, consistency: :quorum) do
        {:ok, result} ->
          {:ok, result}

        {:error, %Xandra.Error{} = err} ->
          _ = Logger.warning("Database error: #{Exception.message(err)}.", tag: "database_error")
          {:error, :database_error}

        {:error, %Xandra.ConnectionError{} = err} ->
          _ =
            Logger.warning("Database connection error: #{Exception.message(err)}.",
              tag: "database_connection_error"
            )

          {:error, :database_connection_error}
      end
    end
  end

  defp do_delete_datastream_maximum_storage_retention(conn, realm_name) do
    statement = """
    DELETE FROM :realm_name.kv_store
    WHERE group='realm_config' AND key='datastream_maximum_storage_retention'
    """

    # TODO move away from this when NoaccOS' PR is merged
    query = String.replace(statement, ":realm_name", realm_name)

    # TODO refactor when NoaccOS' PR is merged
    with {:ok, prepared} <- Xandra.prepare(conn, query),
         {:ok, result} <- Xandra.execute(conn, prepared, %{}, consistency: :quorum) do
      {:ok, result}
    else
      {:error, %Xandra.Error{} = err} ->
        _ = Logger.warning("Database error: #{Exception.message(err)}.", tag: "database_error")
        {:error, :database_error}

      {:error, %Xandra.ConnectionError{} = err} ->
        _ =
          Logger.warning("Database connection error: #{Exception.message(err)}.",
            tag: "database_connection_error"
          )

        {:error, :database_connection_error}
    end
  end
end
