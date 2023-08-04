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

defmodule Astarte.Pairing.DatabaseTestHelper do
  alias Astarte.Core.Device
  alias Astarte.Pairing.Queries
  alias Astarte.Pairing.TestHelper
  alias Astarte.Pairing.CredentialsSecret
  alias Astarte.Pairing.CredentialsSecret.Cache

  @test_realm "autotestrealm"

  @create_autotestrealm """
  CREATE KEYSPACE #{@test_realm}
    WITH
    replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
    durable_writes = true;
  """

  @create_devices_table """
  CREATE TABLE #{@test_realm}.devices (
    device_id uuid,
    introspection map<ascii, int>,
    introspection_minor map<ascii, int>,
    protocol_revision int,
    triggers set<ascii>,
    first_registration timestamp,
    inhibit_credentials_request boolean,
    credentials_secret ascii,
    cert_serial ascii,
    cert_aki ascii,
    first_credentials_request timestamp,
    last_connection timestamp,
    last_disconnection timestamp,
    connected boolean,
    pending_empty_cache boolean,
    total_received_msgs bigint,
    total_received_bytes bigint,
    last_credentials_request_ip inet,
    last_seen_ip inet,

    PRIMARY KEY (device_id)
  );
  """

  @create_kv_store_table """
  CREATE TABLE #{@test_realm}.kv_store (
    group varchar,
    key varchar,
    value blob,

    PRIMARY KEY ((group), key)
  );
  """

  @jwt_public_key_pem """
  -----BEGIN PUBLIC KEY-----
  MFYwEAYHKoZIzj0CAQYFK4EEAAoDQgAE7u5hHn9oE9uy5JoUjwNU6rSEgRlAFh5e
  u9/f1dNImWDuIPeLu8nEiuHlCMy02+YDu0wN2U1psPC7w6AFjv4uTg==
  -----END PUBLIC KEY-----
  """

  @insert_jwt_public_key_pem """
  INSERT INTO #{@test_realm}.kv_store (group, key, value)
  VALUES ('auth', 'jwt_public_key_pem', varcharAsBlob('#{@jwt_public_key_pem}'))
  """

  @drop_autotestrealm """
  DROP KEYSPACE #{@test_realm};
  """

  @unregistered_128_bit_hw_id TestHelper.random_128_bit_hw_id()
  @unregistered_256_bit_hw_id TestHelper.random_256_bit_hw_id()

  @registered_not_confirmed_hw_id TestHelper.random_256_bit_hw_id()
  @registered_not_confirmed_credentials_secret CredentialsSecret.generate()

  @registered_and_confirmed_256_hw_id TestHelper.random_256_bit_hw_id()
  @registered_and_confirmed_256_credentials_secret CredentialsSecret.generate()

  @registered_and_confirmed_128_hw_id TestHelper.random_128_bit_hw_id()
  @registered_and_confirmed_128_credentials_secret CredentialsSecret.generate()

  @registered_and_inhibited_hw_id TestHelper.random_256_bit_hw_id()
  @registered_and_inhibited_credentials_secret CredentialsSecret.generate()

  @insert_device """
  INSERT INTO #{@test_realm}.devices
  (device_id, credentials_secret, inhibit_credentials_request, first_registration,
  protocol_revision, total_received_bytes, total_received_msgs, first_credentials_request)
  VALUES (:device_id, :credentials_secret, :inhibit_credentials_request, :first_registration,
  1, 0, 0, :first_credentials_request)
  """

  def test_realm(), do: @test_realm

  def agent_public_key_pems, do: [@jwt_public_key_pem]

  def unregistered_128_bit_hw_id(), do: @unregistered_128_bit_hw_id

  def unregistered_256_bit_hw_id(), do: @unregistered_256_bit_hw_id

  def registered_not_confirmed_hw_id(), do: @registered_not_confirmed_hw_id

  def registered_not_confirmed_credentials_secret(),
    do: @registered_not_confirmed_credentials_secret

  def registered_and_confirmed_256_hw_id(), do: @registered_and_confirmed_256_hw_id

  def registered_and_confirmed_256_credentials_secret(),
    do: @registered_and_confirmed_256_credentials_secret

  def registered_and_confirmed_128_hw_id(), do: @registered_and_confirmed_128_hw_id

  def registered_and_confirmed_128_credentials_secret(),
    do: @registered_and_confirmed_128_credentials_secret

  def registered_and_inhibited_hw_id(), do: @registered_and_inhibited_hw_id

  def registered_and_inhibited_credentials_secret(),
    do: @registered_and_inhibited_credentials_secret

  # https://github.com/lexhide/xandra/blob/47cabaa3a5ae49127f1a9da91acd003f5ada7c1d/test/support/test_helper.ex#L7C15-L7C15
  def await_cluster_connected(cluster \\ nil, tries \\ 10) do
    cluster = cluster || Application.get_env(:astarte_pairing, :cluster_name)
    fun = &Xandra.execute!(&1, "SELECT * FROM system.local")

    with {:error, %Xandra.ConnectionError{}} <- Xandra.Cluster.run(cluster, _options = [], fun) do
      if tries > 0 do
        Process.sleep(100)
        await_cluster_connected(cluster, tries - 1)
      else
        raise("Connection to the cluster failed")
      end
    end
  end

  def create_db do
    with {:ok, _} <- Queries.custom_query(@create_autotestrealm),
         {:ok, _} <- Queries.custom_query(@create_devices_table),
         {:ok, _} <- Queries.custom_query(@create_kv_store_table),
         {:ok, _} <- Queries.custom_query(@insert_jwt_public_key_pem) do
      :ok
    end
  end

  def seed_agent_public_key_pem do
  end

  def seed_devices do
    {:ok, registered_not_confirmed_device_id} =
      Device.decode_device_id(@registered_not_confirmed_hw_id, allow_extended_id: true)

    secret_hash = CredentialsSecret.hash(@registered_not_confirmed_credentials_secret)

    registered_not_confirmed_params = %{
      "device_id" => registered_not_confirmed_device_id,
      "credentials_secret" => secret_hash,
      "inhibit_credentials_request" => false,
      "first_registration" => TestHelper.now_millis(),
      "first_credentials_request" => nil
    }

    {:ok, registered_and_confirmed_256_device_id} =
      Device.decode_device_id(@registered_and_confirmed_256_hw_id, allow_extended_id: true)

    secret_hash = CredentialsSecret.hash(@registered_and_confirmed_256_credentials_secret)

    registered_and_confirmed_256_params = %{
      "device_id" => registered_and_confirmed_256_device_id,
      "credentials_secret" => secret_hash,
      "inhibit_credentials_request" => false,
      "first_registration" => TestHelper.now_millis(),
      "first_credentials_request" => TestHelper.now_millis()
    }

    {:ok, registered_and_confirmed_128_device_id} =
      Device.decode_device_id(@registered_and_confirmed_128_hw_id, allow_extended_id: true)

    secret_hash = CredentialsSecret.hash(@registered_and_confirmed_128_credentials_secret)

    registered_and_confirmed_128_params = %{
      "device_id" => registered_and_confirmed_128_device_id,
      "credentials_secret" => secret_hash,
      "inhibit_credentials_request" => false,
      "first_registration" => TestHelper.now_millis(),
      "first_credentials_request" => TestHelper.now_millis()
    }

    {:ok, registered_and_inhibited_device_id} =
      Device.decode_device_id(@registered_and_inhibited_hw_id, allow_extended_id: true)

    secret_hash = CredentialsSecret.hash(@registered_and_inhibited_credentials_secret)

    registered_and_inhibited_params = %{
      "device_id" => registered_and_inhibited_device_id,
      "credentials_secret" => secret_hash,
      "inhibit_credentials_request" => true,
      "first_registration" => TestHelper.now_millis(),
      "first_credentials_request" => TestHelper.now_millis()
    }

    with {:ok, _} <-
           Queries.custom_query(@insert_device, @test_realm, registered_not_confirmed_params),
         {:ok, _} <-
           Queries.custom_query(@insert_device, @test_realm, registered_and_confirmed_256_params),
         {:ok, _} <-
           Queries.custom_query(@insert_device, @test_realm, registered_and_confirmed_128_params),
         {:ok, _} <-
           Queries.custom_query(@insert_device, @test_realm, registered_and_inhibited_params) do
      :ok
    end
  end

  def get_first_registration(hardware_id) do
    {:ok, device_id} = Device.decode_device_id(hardware_id, allow_extended_id: true)

    statement = """
    SELECT first_registration
    FROM #{@test_realm}.devices
    WHERE device_id=:device_id
    """

    params = %{"device_id" => device_id}

    with {:ok, result} <- Queries.custom_query(statement, @test_realm, params, result: :first),
         %{"first_registration" => first_registration} <- result do
      first_registration
    end
  end

  def get_introspection(hardware_id) do
    {:ok, device_id} = Device.decode_device_id(hardware_id, allow_extended_id: true)

    statement = """
    SELECT introspection
    FROM #{@test_realm}.devices
    WHERE device_id=:device_id
    """

    params = %{"device_id" => device_id}

    with {:ok, result} <- Queries.custom_query(statement, @test_realm, params, result: :first!) do
      %{"introspection" => introspection} = result
      introspection
    end
  end

  def get_introspection_minor(hardware_id) do
    {:ok, device_id} = Device.decode_device_id(hardware_id, allow_extended_id: true)

    statement = """
    SELECT introspection_minor
    FROM #{@test_realm}.devices
    WHERE device_id=:device_id
    """

    params = %{"device_id" => device_id}

    with {:ok, result} <- Queries.custom_query(statement, @test_realm, params, result: :first!) do
      %{"introspection_minor" => introspection_minor} = result
      introspection_minor
    end
  end

  def clean_devices do
    Queries.custom_query("TRUNCATE #{@test_realm}.devices")
    # Also clean the cache
    Cache.flush()

    :ok
  end

  def drop_db do
    Queries.custom_query(@drop_autotestrealm)
    # Also clean the cache
    Cache.flush()
  end
end
