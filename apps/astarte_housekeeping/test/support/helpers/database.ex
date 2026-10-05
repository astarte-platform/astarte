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

defmodule Astarte.Housekeeping.Helpers.Database do
  @moduledoc false
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.Housekeeping.Realms.Queries

  @create_keyspace """
  CREATE KEYSPACE :keyspace
    WITH
      replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
      durable_writes = true;
  """

  @drop_keyspace """
    DROP KEYSPACE IF EXISTS :keyspace
  """

  @insert_public_key """
    INSERT INTO :keyspace.kv_store (group, key, value)
    VALUES ('auth', 'jwt_public_key_pem', varcharAsBlob(:pem));
  """

  @jwt_public_key_pem """
    -----BEGIN PUBLIC KEY-----
    MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAE7u5hHn9oE9uy5JoUjwNU6rSEgRlAFh5e
    u9/f1dNImWDuIPeLu8nEiuHlCMy02+YDu0wN2U1psPC7w6AFjv4uTg==
    -----END PUBLIC KEY-----
  """

  def setup_database(realm_name) do
    setup_astarte_keyspace()
    setup_realm_keyspace(realm_name)
    insert_public_key(realm_name)

    :ok
  end

  def setup_database_access(astarte_instance_id) do
    Astarte.DataAccess.Config
    |> Mimic.stub(:astarte_instance_id, fn -> {:ok, astarte_instance_id} end)
    |> Mimic.stub(:astarte_instance_id!, fn -> astarte_instance_id end)
  end

  def setup_realm_keyspace(realm_name, public_key_pem \\ "") do
    Queries.create_realm(realm_name, public_key_pem, nil, nil, nil, [])
  end

  def setup_astarte_keyspace do
    astarte_keyspace = Realm.astarte_keyspace_name()
    execute(astarte_keyspace, @create_keyspace)
    Database.migrate_astarte()
    Queries.save_keyspace_replication({:network_topology_strategy, %{"datacenter1" => 1}})

    :ok
  end

  def teardown(realm_name) do
    teardown_astarte_keyspace()
    teardown_realm_keyspace(realm_name)

    :ok
  end

  def teardown_realm_keyspace(realm_name) do
    astarte_keyspace = Realm.astarte_keyspace_name()
    realm_keyspace = Realm.keyspace_name(realm_name)
    execute(realm_keyspace, @drop_keyspace)

    Repo.safe_delete(%Realm{realm_name: realm_name}, prefix: astarte_keyspace)
    :ok
  end

  def teardown_astarte_keyspace do
    astarte_keyspace = Realm.astarte_keyspace_name()
    execute(astarte_keyspace, @drop_keyspace)
    :ok
  end

  def insert_public_key(realm_name) do
    realm_keyspace = Realm.keyspace_name(realm_name)

    execute(realm_keyspace, @insert_public_key, %{"pem" => @jwt_public_key_pem})
  end

  defp execute(keyspace, query, params \\ [], opts \\ []) do
    Repo.query(String.replace(query, ":keyspace", keyspace), params, opts)
  end

  def lightweight_transaction_check(keyspace_name) do
    lwt_query = """
    INSERT INTO #{keyspace_name}.kv_store (group, key, value)
    VALUES ('test', 'test', intAsBlob(0))
    IF NOT EXISTS
    """

    Repo.query(lwt_query)
  end
end
