defmodule Astarte.DataAccess.DatabaseTestHelper do
  require IEx
  @realm_test "astartetest"

  @create_test """
    CREATE KEYSPACE #{@realm_test}
      WITH
        replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
        durable_writes = true;
  """

  @create_kv_store """
    CREATE TABLE #{@realm_test}.kv_store (
      group varchar,
      key varchar,
      value blob,
      PRIMARY KEY ((group), key)
    );
  """

  @create_names_table """
    CREATE TABLE #{@realm_test}.names (
      object_name varchar,
      object_type int,
      object_uuid uuid,
      PRIMARY KEY ((object_name), object_type)
    );
  """

  @create_groups_table """
    CREATE TABLE #{@realm_test}.grouped_devices (
      group_name varchar,
      insertion_uuid timeuuid,
      device_id uuid,
      PRIMARY KEY ((group_name), insertion_uuid, device_id)
    );
  """

  @create_devices_table """
    CREATE TABLE #{@realm_test}.devices (
    device_id uuid PRIMARY KEY,
    aliases map<ascii, text>,
    cert_aki ascii,
    cert_serial ascii,
    connected boolean,
    credentials_secret ascii,
    exchanged_bytes_by_interface map<frozen<tuple<ascii, int>>, bigint>,
    exchanged_msgs_by_interface map<frozen<tuple<ascii, int>>, bigint>,
    first_credentials_request timestamp,
    first_registration timestamp,
    groups map<text, timeuuid>,
    inhibit_credentials_request boolean,
    introspection map<ascii, int>,
    introspection_minor map<ascii, int>,
    last_connection timestamp,
    last_credentials_request_ip inet,
    last_disconnection timestamp,
    last_seen_ip inet,
    old_introspection map<frozen<tuple<ascii, int>>, int>,
    pending_empty_cache boolean,
    protocol_revision int,
    total_received_bytes bigint,
    total_received_msgs bigint
  )
  """
  @create_interfaces_table """
   CREATE TABLE #{@realm_test}.interfaces (
    name ascii,
    major_version int,
    aggregation int,
    automaton_accepting_states blob,
    automaton_transitions blob,
    description text,
    doc text,
    interface_id uuid,
    minor_version int,
    ownership int,
    storage ascii,
    storage_type int,
    type int,
    PRIMARY KEY (name, major_version)
  )
  """

  @create_endpoints_table """
  CREATE TABLE #{@realm_test}.endpoints (
    interface_id uuid,
    endpoint_id uuid,
    allow_unset boolean,
    database_retention_policy int,
    database_retention_ttl int,
    description text,
    doc text,
    endpoint ascii,
    expiry int,
    explicit_timestamp boolean,
    interface_major_version int,
    interface_minor_version int,
    interface_name ascii,
    interface_type int,
    reliability int,
    retention int,
    value_type int,
    PRIMARY KEY (interface_id, endpoint_id)
  )
  """

  @create_individual_properties_table """
    CREATE TABLE #{@realm_test}.individual_properties (
    device_id uuid,
    interface_id uuid,
    endpoint_id uuid,
    path text,
    binaryblob_value blob,
    binaryblobarray_value list<blob>,
    boolean_value boolean,
    booleanarray_value list<boolean>,
    datetime_value timestamp,
    datetimearray_value list<timestamp>,
    double_value double,
    doublearray_value list<double>,
    integer_value int,
    integerarray_value list<int>,
    longinteger_value bigint,
    longintegerarray_value list<bigint>,
    reception_timestamp timestamp,
    reception_timestamp_submillis smallint,
    string_value text,
    stringarray_value list<text>,
    PRIMARY KEY ((device_id, interface_id), endpoint_id, path)
  )
  """

  @create_individual_datastreams_table """
    CREATE TABLE #{@realm_test}.individual_datastreams (
    device_id uuid,
    interface_id uuid,
    endpoint_id uuid,
    path text,
    value_timestamp timestamp,
    reception_timestamp timestamp,
    reception_timestamp_submillis smallint,
    binaryblob_value blob,
    binaryblobarray_value list<blob>,
    boolean_value boolean,
    booleanarray_value list<boolean>,
    datetime_value timestamp,
    datetimearray_value list<timestamp>,
    double_value double,
    doublearray_value list<double>,
    integer_value int,
    integerarray_value list<int>,
    longinteger_value bigint,
    longintegerarray_value list<bigint>,
    string_value text,
    stringarray_value list<text>,
    PRIMARY KEY ((device_id, interface_id, endpoint_id, path), value_timestamp, reception_timestamp, reception_timestamp_submillis))
  """

  @create_objects_table """
    CREATE TABLE #{@realm_test}.objectdatastreams_org_v0 (
    device_id uuid,
    path text,
    reception_timestamp timestamp,
    reception_timestamp_submillis smallint,
    v_d bigint,
    v_x double,
    v_y int,
    PRIMARY KEY ((device_id, path), reception_timestamp, reception_timestamp_submillis)
  )
  """

  @interfaces [
    """
    INSERT INTO #{@realm_test}.interfaces (name, major_version , aggregation , automaton_accepting_states, automaton_transitions, description, doc, interface_id, minor_version, ownership, storage, storage_type, type) VALUES
      ('properties.org' ,0 , 1 , 0x83740000000261016d00000010a34e43107a717778bf705aa9f8ca12bb61026d000000103cf56aaa4e7710a461837fc5df23c1aa ,0x837400000002680261006d0000000b70726f70657274696573316101680261006d0000000b70726f70657274696573326102 ,null , null , 3133ef79-32e6-5166-92fd-334f376348c4 , 1 , 1 , 'individual_properties' , 1, 1)
    """,
    """
    INSERT INTO #{@realm_test}.interfaces (name, major_version , aggregation , automaton_accepting_states, automaton_transitions, description, doc, interface_id, minor_version, ownership, storage, storage_type, type) VALUES
      ('org.individualdatastreams.values' ,0 ,1 ,0x83740000000561016d000000108ae8200406bde60925ae12f664d03b3d61026d00000010efd6d81b95f4c59af98b047ccbd1816861036d00000010f6c184b4beb73cbccd61e86dba4d0c6861046d00000010aca7e5cd7d5a62016cc44d5aedfff3b561056d000000108b7ee53ce3f9f4f92b0b10323777e4c8 , 0x837400000005680261006d0000000c74657374696e7374616c6c316101680261006d0000000c74657374696e7374616c6c326102680261006d0000000c74657374696e7374616c6c336103680261006d0000000c74657374696e7374616c6c346104680261006d0000000c74657374696e7374616c6c356105 , null, null, d796876e-5b72-9e9f-7d5d-28c450282cac, 1, 1, 'individual_datastreams', 2, 2)
    """,
    """
    INSERT INTO #{@realm_test}.interfaces (name, major_version , aggregation , automaton_accepting_states, automaton_transitions, description, doc, interface_id, minor_version, ownership, storage, storage_type, type) VALUES
      ('objectdatastreams.org' , 0, 2, 0x83740000000361026d00000010fa73d5001ebffe12d38c3cbcad5cc38861036d00000010731d79ec776e0d4b61da731f4fb9c89561046d00000010ea80b251fae50f5e37f945b9b4f71f5b, 0x837400000004680261006d0000000f6f626a656374656e64706f696e74316101680261016d00000001646104680261016d00000001786102680261016d00000001796103 , null , null , f7d5e358-c4e7-1ec7-521c-5f71cfb44667 , 1 , 1 , 'objectdatastreams_org_v0' , 5 , 2)
    """
  ]

  @endpoints [
    """
        INSERT INTO #{@realm_test}.endpoints (interface_id, endpoint_id, allow_unset, database_retention_policy, database_retention_ttl, description, doc, endpoint, expiry , explicit_timestamp, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (d796876e-5b72-9e9f-7d5d-28c450282cac , aca7e5cd-7d5a-6201-6cc4-4d5aedfff3b5, false , 1 ,null ,null , null ,      '/testinstall4' ,0 ,False ,0 ,1 , 'org.individualdatastreams.values' ,2 ,1 ,1 ,7);
    """,
    """
        INSERT INTO #{@realm_test}.endpoints (interface_id, endpoint_id, allow_unset, database_retention_policy, database_retention_ttl, description, doc, endpoint, expiry , explicit_timestamp, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (d796876e-5b72-9e9f-7d5d-28c450282cac , f6c184b4-beb7-3cbc-cd61-e86dba4d0c68, false , 1 ,null ,null , null ,      '/testinstall3' ,0 ,False ,0 ,1 , 'org.individualdatastreams.values' ,2 ,1 ,1 ,9);
    """,
    """
        INSERT INTO #{@realm_test}.endpoints (interface_id, endpoint_id, allow_unset, database_retention_policy, database_retention_ttl, description, doc, endpoint, expiry , explicit_timestamp, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (d796876e-5b72-9e9f-7d5d-28c450282cac , efd6d81b-95f4-c59a-f98b-047ccbd18168, false , 1 ,null ,null , null ,      '/testinstall2' ,0 ,False ,0 ,1 , 'org.individualdatastreams.values' ,2 ,1 ,1 ,3);
    """,
    """
        INSERT INTO #{@realm_test}.endpoints (interface_id, endpoint_id, allow_unset, database_retention_policy, database_retention_ttl, description, doc, endpoint, expiry , explicit_timestamp, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (d796876e-5b72-9e9f-7d5d-28c450282cac , 8ae82004-06bd-e609-25ae-12f664d03b3d, false , 1 ,null ,null , null ,      '/testinstall1' ,0 ,False ,0 ,1 , 'org.individualdatastreams.values' ,2 ,1 ,1 ,1);
    """,
    """
        INSERT INTO #{@realm_test}.endpoints (interface_id, endpoint_id, allow_unset, database_retention_policy, database_retention_ttl, description, doc, endpoint, expiry , explicit_timestamp, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (d796876e-5b72-9e9f-7d5d-28c450282cac , 8ae82004-06bd-e609-25ae-12f664d03b3d, false , 1 ,null ,null , null ,      '/testinstall1' ,0 ,False ,0 ,1 , 'org.individualdatastreams.values' ,2 ,1 ,1 ,1);
    """,
    """
        INSERT INTO #{@realm_test}.endpoints (interface_id, endpoint_id, allow_unset, database_retention_policy, database_retention_ttl, description, doc, endpoint, expiry , explicit_timestamp, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (d796876e-5b72-9e9f-7d5d-28c450282cac , 8b7ee53c-e3f9-f4f9-2b0b-10323777e4c8, false , 1 ,null ,null , null ,      '/testinstall5' ,0 ,False ,0 ,1 , 'org.individualdatastreams.values' ,2 ,1 ,1 ,5);
    """,
    """
        INSERT INTO #{@realm_test}.endpoints (interface_id, endpoint_id, allow_unset, database_retention_policy, database_retention_ttl, description, doc, endpoint, expiry , explicit_timestamp, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (3133ef79-32e6-5166-92fd-334f376348c4 , 3cf56aaa-4e77-10a4-6183-7fc5df23c1aa, false , 1 ,null ,null , null ,       '/properties2' ,0 ,False ,0 ,1 ,                   'properties.org' ,1 ,1 ,1 ,7);
    """,
    """
        INSERT INTO #{@realm_test}.endpoints (interface_id, endpoint_id, allow_unset, database_retention_policy, database_retention_ttl, description, doc, endpoint, expiry , explicit_timestamp, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (3133ef79-32e6-5166-92fd-334f376348c4 , a34e4310-7a71-7778-bf70-5aa9f8ca12bb, false , 1 ,null ,null , null ,       '/properties1' ,0 ,False ,0 ,1 ,                   'properties.org' ,1 ,1 ,1 ,1);
    """,
    """
        INSERT INTO #{@realm_test}.endpoints (interface_id, endpoint_id, allow_unset, database_retention_policy, database_retention_ttl, description, doc, endpoint, expiry , explicit_timestamp, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (f7d5e358-c4e7-1ec7-521c-5f71cfb44667 , ea80b251-fae5-0f5e-37f9-45b9b4f71f5b, false , 1 ,null ,null , null , '/objectendpoint1/d' ,0 ,False ,0 ,1 ,            'objectdatastreams.org' ,2 ,1 ,1 ,5);
    """,
    """
        INSERT INTO #{@realm_test}.endpoints (interface_id, endpoint_id, allow_unset, database_retention_policy, database_retention_ttl, description, doc, endpoint, expiry , explicit_timestamp, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (f7d5e358-c4e7-1ec7-521c-5f71cfb44667 , 731d79ec-776e-0d4b-61da-731f4fb9c895, false , 1 ,null ,null , null , '/objectendpoint1/y' ,0 ,False ,0 ,1 ,            'objectdatastreams.org' ,2 ,1 ,1 ,3);
    """,
    """
        INSERT INTO #{@realm_test}.endpoints (interface_id, endpoint_id, allow_unset, database_retention_policy, database_retention_ttl, description, doc, endpoint, expiry , explicit_timestamp, interface_major_version, interface_minor_version, interface_name, interface_type, reliability, retention, value_type) VALUES
        (f7d5e358-c4e7-1ec7-521c-5f71cfb44667 , fa73d500-1ebf-fe12-d38c-3cbcad5cc388, false , 1 ,null ,null , null , '/objectendpoint1/x' ,0 ,False ,0 ,1 ,            'objectdatastreams.org' ,2 ,1 ,1 ,1);
    """
  ]

  @devices [
    """
    INSERT INTO #{@realm_test}.devices (device_id, aliases, cert_aki, cert_serial, connected, credentials_secret, exchanged_bytes_by_interface, exchanged_msgs_by_interface, first_credentials_request, first_registration, groups, inhibit_credentials_request, introspection, introspection_minor, last_connection, last_credentials_request_ip, last_disconnection, last_seen_ip, old_introspection, pending_empty_cache, protocol_revision, total_received_bytes, total_received_msgs) VALUES (c8a03708-c774-ee45-9a0f-28fa68c3f80e, null, 'a8eaf08a797f0b10bb9e7b5dca027ec2571c5ea6', '324725654494785828109237459525026742139358888604', False, 'null', null, null, '2019-05-30 13:49:57.355+0000', '2019-05-30 13:49:57.045+0000', null, False, {'objectdatastreams.org': 0, 'org.individualdatastreams.values': 0, 'properties.org': 0}, {'objectdatastreams.org': 1, 'org.individualdatastreams.values': 1, 'properties.org': 1}, '2019-05-30 13:49:57.561+0000', '198.51.100.1', '2019-05-30 13:51:00.038+0000', '198.51.100.89', null, False, 0, 3960, 64);
    """
  ]

  @drop_keyspace """
  DROP KEYSPACE #{@realm_test};
  """

  @delete_realm_from_astarte_realms """
  DELETE FROM astarte.realms WHERE realm_name = '#{@realm_test}';
  """

  def create_test_keyspace(conn) do
    Xandra.execute(conn, @drop_keyspace, [], [])

    {:ok,
     %Xandra.SchemaChange{
       effect: "CREATED",
       options: %{keyspace: "#{@realm_test}"},
       target: "KEYSPACE",
       tracing_id: nil
     }} = Xandra.execute(conn, @create_test, [], [])

    :timer.sleep(2000)

    create_tables = [
      @create_kv_store,
      @create_names_table,
      @create_groups_table,
      @create_devices_table,
      @create_interfaces_table,
      @create_endpoints_table,
      @create_individual_properties_table,
      @create_individual_datastreams_table,
      @create_objects_table
    ]

    Enum.each(
      create_tables,
      fn table_statement ->
        {:ok, %Xandra.SchemaChange{}} = Xandra.execute(conn, table_statement, [], [])
      end
    )

    :timer.sleep(3000)

    Enum.each(
      @devices,
      fn statement ->
        {:ok, _} = Xandra.execute(conn, statement, [], [])
      end
    )

    Enum.each(
      @interfaces,
      fn interface ->
        {:ok, _} = Xandra.execute(conn, interface, [], [])
      end
    )
  end

  def seed_data(conn) do
    Enum.each(
      @devices,
      fn statement ->
        {:ok, _} = Xandra.execute(conn, statement, [], [])
      end
    )

    Enum.each(
      @interfaces,
      fn interface ->
        {:ok, _} = Xandra.execute(conn, interface, [], [])
      end
    )

    Enum.each(
      @endpoints,
      fn statement ->
        {:ok, _} = Xandra.execute(conn, statement, [], [])
      end
    )
  end

  def drop_test_keyspace(conn) do
    Xandra.execute(conn, @drop_keyspace, [], [])
    Xandra.execute(conn, @delete_realm_from_astarte_realms, [], [])
  end
end
