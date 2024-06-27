defmodule Astarte.Test.Helpers.Database do
  alias Astarte.Core.Device
  alias Astarte.Core.Interface
  alias Astarte.Core.Interface.Type, as: InterfaceType
  alias Astarte.Core.Interface.Aggregation, as: AggregationType
  alias Astarte.Core.Interface.Ownership, as: OwnershipType

  ###
  ### Keyspace
  @create_keyspace """
  CREATE KEYSPACE :keyspace
    WITH
      replication = {'class': 'SimpleStrategy', 'replication_factor': '1'} AND
      durable_writes = true;
  """

  @drop_keyspace """
  DROP KEYSPACE :keyspace
  """

  ###
  ### Tables
  @create_kv_store """
  CREATE TABLE :keyspace.kv_store (
    group varchar,
    key varchar,
    value blob,

    PRIMARY KEY ((group), key)
  )
  """

  @create_names_table """
  CREATE TABLE :keyspace.names (
    object_name varchar,
    object_type int,
    object_uuid uuid,

    PRIMARY KEY ((object_name), object_type)
  )
  """

  @create_devices_table """
  CREATE TABLE :keyspace.devices (
    device_id uuid,
    aliases map<ascii, varchar>,
    introspection map<ascii, int>,
    introspection_minor map<ascii, int>,
    old_introspection map<frozen<tuple<ascii, int>>, int>,
    protocol_revision int,
    first_registration timestamp,
    credentials_secret ascii,
    inhibit_credentials_request boolean,
    cert_serial ascii,
    cert_aki ascii,
    first_credentials_request timestamp,
    last_connection timestamp,
    last_disconnection timestamp,
    connected boolean,
    pending_empty_cache boolean,
    total_received_msgs bigint,
    total_received_bytes bigint,
    exchanged_msgs_by_interface map<frozen<tuple<ascii, int>>, bigint>,
    exchanged_bytes_by_interface map<frozen<tuple<ascii, int>>, bigint>,
    last_credentials_request_ip inet,
    last_seen_ip inet,
    groups map<text, timeuuid>,
    attributes map<varchar, varchar>,

    PRIMARY KEY (device_id)
  )
  """

  @create_interfaces_table """
  CREATE TABLE :keyspace.interfaces (
    name ascii,
    major_version int,
    minor_version int,
    interface_id uuid,
    storage_type int,
    storage ascii,
    type int,
    ownership int,
    aggregation int,
    automaton_transitions blob,
    automaton_accepting_states blob,
    description varchar,
    doc varchar,

    PRIMARY KEY (name, major_version)
  )
  """

  @create_endpoints_table """
  CREATE TABLE :keyspace.endpoints (
    interface_id uuid,
    endpoint_id uuid,
    interface_name ascii,
    interface_major_version int,
    interface_minor_version int,
    interface_type int,
    endpoint ascii,
    value_type int,
    reliability int,
    retention int,
    database_retention_policy int,
    database_retention_ttl int,
    expiry int,
    allow_unset boolean,
    explicit_timestamp boolean,
    description varchar,
    doc varchar,

    PRIMARY KEY ((interface_id), endpoint_id)
  )
  """
  @create_individual_properties_table """
  CREATE TABLE :keyspace.individual_properties (
    device_id uuid,
    interface_id uuid,
    endpoint_id uuid,
    path varchar,
    reception_timestamp timestamp,
    reception_timestamp_submillis smallint,

    double_value double,
    integer_value int,
    boolean_value boolean,
    longinteger_value bigint,
    string_value varchar,
    binaryblob_value blob,
    datetime_value timestamp,
    doublearray_value list<double>,
    integerarray_value list<int>,
    booleanarray_value list<boolean>,
    longintegerarray_value list<bigint>,
    stringarray_value list<varchar>,
    binaryblobarray_value list<blob>,
    datetimearray_value list<timestamp>,

    PRIMARY KEY((device_id, interface_id), endpoint_id, path)
  )
  """

  @create_individual_datastreams_table """
  CREATE TABLE :keyspace.individual_datastreams (
    device_id uuid,
    interface_id uuid,
    endpoint_id uuid,
    path varchar,
    value_timestamp timestamp,
    reception_timestamp timestamp,
    reception_timestamp_submillis smallint,

    double_value double,
    integer_value int,
    boolean_value boolean,
    longinteger_value bigint,
    string_value varchar,
    binaryblob_value blob,
    datetime_value timestamp,
    doublearray_value list<double>,
    integerarray_value list<int>,
    booleanarray_value list<boolean>,
    longintegerarray_value list<bigint>,
    stringarray_value list<varchar>,
    binaryblobarray_value list<blob>,
    datetimearray_value list<timestamp>,

    PRIMARY KEY((device_id, interface_id, endpoint_id, path), value_timestamp, reception_timestamp, reception_timestamp_submillis)
  )
  """

  @create_groups_table """
  CREATE TABLE :keyspace.grouped_devices (
    group_name varchar,
    insertion_uuid timeuuid,
    device_id uuid,
    PRIMARY KEY ((group_name), insertion_uuid, device_id)
  )
  """

  ###
  ### Insert
  @insert_interface """
  INSERT INTO :keyspace.interfaces (
    name,
    interface_id,
    major_version,
    minor_version,
    type,
    automaton_accepting_states,
    automaton_transitions,
    aggregation,
    ownership,
    storage,
    storage_type
    ) VALUES (
      :name,
      :interface_id,
      :major_version,
      :minor_version,
      :type,
      :automaton_accepting_states,
      :automaton_transitions,
      :aggregation,
      :ownership,
      :storage,
      :storage_type
    )
  """

  @insert_device """
  INSERT INTO :keyspace.devices
  (
     device_id,
     aliases,
     attributes,
     connected,
     last_connection,
     last_disconnection,
     first_registration,
     first_credentials_request,
     last_seen_ip,
     last_credentials_request_ip,
     total_received_msgs,
     total_received_bytes,
     inhibit_credentials_request,
     introspection,
     introspection_minor,
     exchanged_msgs_by_interface,
     exchanged_bytes_by_interface
  )
  VALUES
  (
    :device_id,
    :aliases,
    :attributes,
    :connected,
    :last_connection,
    :last_disconnection,
    :first_registration,
    :first_credentials_request,
    :last_seen_ip,
    :last_credentials_request_ip,
    :total_received_msgs,
    :total_received_bytes,
    :inhibit_credentials_request,
    :introspection,
    :introspection_minor,
    :exchanged_msgs_by_interface,
    :exchanged_bytes_by_interface
  )
  """

  @insert_alias """
  INSERT INTO :keyspace.names (
    object_name,
    object_type,
    object_uuid
  )
  VALUES (
    :object_name,
    1,
    :object_uuid
  )
  """

  @insert_group """
  INSERT INTO :keyspace.grouped_devices (
    group_name,
    insertion_uuid,
    device_id
    )
  VALUES
  (
    :group_name,
    :insertion_uuid,
    :device_id
  )
  """

  @insert_pubkeypem """
  INSERT INTO :keyspace.kv_store (group, key, value)
  VALUES ('auth', 'jwt_public_key_pem', varcharAsBlob(:pem));
  """

  ###
  ### Update
  @update_device """
  UPDATE :keyspace.devices
  SET :field = :field + :data
  WHERE device_id = :device_id
  """

  ###
  ### Select
  @select_interfaces """
  SELECT * FROM :keyspace.interfaces WHERE name IN :names
  """

  @select_devices """
  SELECT * FROM :keyspace.devices WHERE device_id IN :device_ids
  """

  ###
  ### Delete
  @delete_interface """
  DELETE FROM :keyspace.interfaces WHERE name = :name
  """

  @delete_device """
  DELETE FROM :keyspace.devices WHERE device_id = :device_id
  """

  @delete_alias """
  DELETE FROM :keyspace.names
  WHERE object_name = :object_name
  AND object_type = 1
  """

  @delete_group """
  DELETE FROM :keyspace.grouped_devices WHERE group_name = :group_name
  """

  @delete_pubkeypem """
  DELETE FROM :keyspace.kv_store WHERE group = 'auth' AND key = 'jwt_public_key_pem'
  """

  ###
  ### Keyspace
  def create_test_keyspace!(cluster, keyspace) do
    Xandra.Cluster.execute!(cluster, String.replace(@create_keyspace, ":keyspace", keyspace))

    Xandra.Cluster.execute!(cluster, String.replace(@create_devices_table, ":keyspace", keyspace))
    Xandra.Cluster.execute!(cluster, String.replace(@create_groups_table, ":keyspace", keyspace))
    Xandra.Cluster.execute!(cluster, String.replace(@create_names_table, ":keyspace", keyspace))
    Xandra.Cluster.execute!(cluster, String.replace(@create_kv_store, ":keyspace", keyspace))

    Xandra.Cluster.execute!(
      cluster,
      String.replace(@create_endpoints_table, ":keyspace", keyspace)
    )

    Xandra.Cluster.execute!(
      cluster,
      String.replace(@create_individual_properties_table, ":keyspace", keyspace)
    )

    Xandra.Cluster.execute!(
      cluster,
      String.replace(@create_individual_datastreams_table, ":keyspace", keyspace)
    )

    Xandra.Cluster.execute!(
      cluster,
      String.replace(@create_interfaces_table, ":keyspace", keyspace)
    )
  end

  def destroy_test_keyspace!(cluster, keyspace) do
    Xandra.Cluster.execute!(cluster, String.replace(@drop_keyspace, ":keyspace", keyspace))
  end

  ###
  ### Insert
  def insert!(:pubkeypem, cluster, keyspace, pub_key_pem) do
    query =
      Xandra.Cluster.prepare!(cluster, String.replace(@insert_pubkeypem, ":keyspace", keyspace))

    Xandra.Cluster.execute!(cluster, query, %{
      "pem" => pub_key_pem
    })
  end

  def insert!(:interface, cluster, keyspace, interfaces) do
    prepared =
      Xandra.Cluster.prepare!(cluster, String.replace(@insert_interface, ":keyspace", keyspace))

    batch =
      Enum.reduce(interfaces, Xandra.Batch.new(), fn interface, acc ->
        Xandra.Batch.add(acc, prepared, %{
          "name" => interface.name,
          "interface_id" => interface.interface_id,
          "major_version" => interface.major_version,
          "minor_version" => interface.minor_version,
          "type" => InterfaceType.to_int(interface.type),
          "automaton_accepting_states" => :erlang.term_to_binary(:automaton_accepting_states),
          "automaton_transitions" => :erlang.term_to_binary(:automaton_transitions),
          "aggregation" => AggregationType.to_int(interface.aggregation),
          # TODO Mapping to the other table
          "ownership" => OwnershipType.to_int(interface.ownership),
          "storage" => "individual_properties",
          "storage_type" => 1
        })
      end)

    Xandra.Cluster.execute!(cluster, batch)
  end

  def insert!(:device, cluster, keyspace, devices) do
    prepared_device =
      Xandra.Cluster.prepare!(cluster, String.replace(@insert_device, ":keyspace", keyspace))

    prepared_aliases =
      Xandra.Cluster.prepare!(cluster, String.replace(@insert_alias, ":keyspace", keyspace))

    batch =
      Enum.reduce(devices, Xandra.Batch.new(), fn device, acc ->
        acc =
          Xandra.Batch.add(acc, prepared_device, %{
            "device_id" => device.id,
            "aliases" => device.aliases,
            "attributes" => device.attributes,
            "connected" => device.connected,
            "last_connection" => device.last_connection,
            "last_disconnection" => device.last_disconnection,
            "first_registration" => device.first_registration,
            "first_credentials_request" => device.first_credentials_request,
            "last_seen_ip" => device.last_seen_ip,
            "last_credentials_request_ip" => device.last_credentials_request_ip,
            "total_received_msgs" => device.total_received_msgs,
            "total_received_bytes" => device.total_received_bytes,
            "inhibit_credentials_request" => device.inhibit_credentials_request,
            "introspection" => %{
              "org.astarte-platform.genericsensors.ServerOwnedAggregateObj" => 0
            },
            "introspection_minor" => %{
              "org.astarte-platform.genericsensors.ServerOwnedAggregateObj" => 1
            },
            "exchanged_msgs_by_interface" => device.interfaces_msgs,
            "exchanged_bytes_by_interface" => device.interfaces_bytes
          })

        aliases = if device.aliases != nil, do: device.aliases, else: []

        Enum.reduce(aliases, acc, fn {_, name}, acc ->
          Xandra.Batch.add(acc, prepared_aliases, %{
            "object_name" => name,
            "object_type" => 1,
            "object_uuid" => device.id
          })
        end)
      end)

    Xandra.Cluster.execute!(cluster, batch)
  end

  def insert!(:group, cluster, keyspace, groups) do
    prepared_group =
      Xandra.Cluster.prepare!(cluster, String.replace(@insert_group, ":keyspace", keyspace))

    prepared_device =
      Xandra.Cluster.prepare!(
        cluster,
        String.replace(@update_device, ":keyspace", keyspace)
        |> String.replace(":field", "groups")
      )

    batch =
      Enum.reduce(groups, Xandra.Batch.new(), fn group, acc ->
        Enum.reduce(group.device_ids, acc, fn device_id, acc ->
          uuid = UUID.uuid1()

          acc =
            Xandra.Batch.add(acc, prepared_group, %{
              "group_name" => group.name,
              "insertion_uuid" => uuid,
              "device_id" => device_id
            })

          Xandra.Batch.add(acc, prepared_device, %{
            "device_id" => device_id,
            "data" => %{group.name => uuid}
          })
        end)
      end)

    Xandra.Cluster.execute!(cluster, batch)
  end

  ###
  ### Select
  def select!(:interface, cluster, keyspace, interfaces) do
    prepared =
      Xandra.Cluster.prepare!(cluster, String.replace(@select_interfaces, ":keyspace", keyspace))

    list =
      interfaces
      |> Stream.map(fn %Interface{} = interface -> interface.name end)
      |> Enum.to_list()

    %Xandra.Page{} =
      page =
      Xandra.Cluster.execute!(
        cluster,
        prepared,
        %{
          "names" => list
        }
      )

    Stream.map(page, fn record ->
      %Interface{
        name: record["name"],
        interface_id: record["interface_id"],
        major_version: record["major_version"],
        minor_version: record["minor_version"],
        type: InterfaceType.from_int(record["type"]),
        aggregation: AggregationType.from_int(record["aggregation"]),
        # TODO Mapping from the other table
        ownership: OwnershipType.from_int(record["ownership"])
      }
    end)
    |> Enum.to_list()
  end

  def select!(:device, cluster, keyspace, devices) do
    prepared =
      Xandra.Cluster.prepare!(cluster, String.replace(@select_devices, ":keyspace", keyspace))

    list =
      devices
      |> Stream.map(fn device -> device.device_id end)
      |> Enum.to_list()

    %Xandra.Page{} =
      page =
      Xandra.Cluster.execute!(
        cluster,
        prepared,
        %{
          "device_ids" => list
        },
        uuid_format: :binary
      )

    Stream.map(page, fn record ->
      %{
        id: record["device_id"],
        device_id: record["device_id"],
        encoded_id: record["device_id"] |> Device.encode_device_id(),
        aliases: record["aliases"],
        attributes: record["attributes"],
        connected: record["connected"],
        last_connection: record["last_connection"],
        last_disconnection: record["last_disconnection"],
        first_registration: record["first_registration"],
        first_credentials_request: record["first_credentials_request"],
        last_seen_ip: record["last_seen_ip"],
        last_credentials_request_ip: record["last_credentials_request_ip"],
        total_received_msgs: record["total_received_msgs"],
        total_received_bytes: record["total_received_bytes"],
        inhibit_credentials_request: record["inhibit_credentials_request"],
        exchanged_msgs_by_interface: record["exchanged_msgs_by_interface"],
        exchanged_bytes_by_interface: record["exchanged_bytes_by_interface"]
      }
    end)
    |> Enum.to_list()
  end

  ###
  ### Delete
  def delete!(:pubkeypem, cluster, keyspace) do
    Xandra.Cluster.execute!(cluster, String.replace(@delete_pubkeypem, ":keyspace", keyspace))
  end

  def delete!(:interface, cluster, keyspace, interfaces) do
    prepared =
      Xandra.Cluster.prepare!(cluster, String.replace(@delete_interface, ":keyspace", keyspace))

    batch =
      Enum.reduce(interfaces, Xandra.Batch.new(), fn interface, acc ->
        Xandra.Batch.add(acc, prepared, %{
          "name" => interface.name
        })
      end)

    Xandra.Cluster.execute!(cluster, batch)
  end

  def delete!(:device, cluster, keyspace, devices) do
    prepared_alias =
      Xandra.Cluster.prepare!(cluster, String.replace(@delete_alias, ":keyspace", keyspace))

    prepared_device =
      Xandra.Cluster.prepare!(cluster, String.replace(@delete_device, ":keyspace", keyspace))

    batch =
      Enum.reduce(devices, Xandra.Batch.new(), fn device, acc ->
        aliases = if device.aliases != nil, do: device.aliases, else: []

        acc =
          Enum.reduce(aliases, acc, fn {_, name}, acc ->
            Xandra.Batch.add(acc, prepared_alias, %{
              "object_name" => name,
              "object_type" => 1
            })
          end)

        Xandra.Batch.add(acc, prepared_device, %{
          "device_id" => device.device_id
        })
      end)

    Xandra.Cluster.execute!(cluster, batch)
  end

  def delete!(:group, cluster, keyspace, groups) do
    prepared_group =
      Xandra.Cluster.prepare!(cluster, String.replace(@delete_group, ":keyspace", keyspace))

    batch =
      Enum.reduce(groups, Xandra.Batch.new(), fn group, acc ->
        Xandra.Batch.add(acc, prepared_group, %{
          "group_name" => group.name
        })
      end)

    Xandra.Cluster.execute!(cluster, batch)
  end
end
