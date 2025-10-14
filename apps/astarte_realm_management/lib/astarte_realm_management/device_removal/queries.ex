defmodule Astarte.RealmManagement.DeviceRemoval.Queries do
  require Logger
  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.Groups.GroupedDevice
  alias Astarte.DataAccess.Realms.Name
  alias Astarte.DataAccess.Realms.IndividualDatastream
  alias Astarte.DataAccess.Devices.Device, as: RealmsDevice
  alias Astarte.DataAccess.Realms.Interface
  alias Astarte.DataAccess.Realms.IndividualProperty
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.KvStore
  alias Astarte.DataAccess.Consistency
  alias Astarte.Core.CQLUtils
  alias Astarte.DataAccess.Realms.Endpoint

  import Ecto.Query

  def table_exist?(realm_name, table_name) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from schema in "system_schema.tables",
        select: schema.table_name,
        where: [table_name: ^table_name, keyspace_name: ^keyspace]

    {:ok, some?} = Repo.some?(query, consistency: Consistency.domain_model(:read))

    some?
  end

  def fetch_device_groups(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)

    opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:read)
    ]
    
    DeletionInProgress
    |> select([d], d.groups)
    |> Repo.fetch(device_id, opts)
  end

  def retrieve_individual_datastreams_keys!(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from IndividualDatastream,
        hints: ["ALLOW FILTERING"],
        distinct: true,
        select: [:device_id, :interface_id, :endpoint_id, :path],
        where: [device_id: ^device_id]

    opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:read)
    ]

    Repo.all(query, opts)
  end

  def delete_individual_datastream_values!(
        realm_name,
        device_id,
        interface_id,
        endpoint_id,
        path
      ) do
    keyspace_name = Realm.keyspace_name(realm_name)

    query =
      from IndividualDatastream,
        where: [
          device_id: ^device_id,
          interface_id: ^interface_id,
          endpoint_id: ^endpoint_id,
          path: ^path
        ]

    opts = [
      prefix: keyspace_name,
      consistency: Consistency.device_info(:write)
    ]

    _ = Repo.delete_all(query, opts)

    :ok
  end

  def retrieve_individual_properties_keys!(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from IndividualProperty,
        hints: ["ALLOW FILTERING"],
        distinct: true,
        select: [:device_id, :interface_id],
        where: [device_id: ^device_id]

    opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:read)
    ]

    Repo.all(query, opts)
  end

  def delete_individual_properties_values!(realm_name, device_id, interface_id) do
    keyspace_name = Realm.keyspace_name(realm_name)

    query =
      from IndividualProperty,
        where: [device_id: ^device_id, interface_id: ^interface_id]

    opts = [
      prefix: keyspace_name,
      consistency: Consistency.device_info(:write)
    ]

    _ = Repo.delete_all(query, opts)

    :ok
  end

  def retrieve_object_datastream_keys!(realm_name, device_id, table_name) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from table_name,
        hints: ["ALLOW FILTERING"],
        distinct: true,
        select: [:device_id, :path],
        where: [device_id: ^device_id]

    opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:read)
    ]

    Repo.all(query, opts)
  end

  def delete_object_datastream_values!(realm_name, device_id, path, table_name) do
    keyspace_name = Realm.keyspace_name(realm_name)

    query =
      from table_name,
        where: [device_id: ^device_id, path: ^path]

    opts = [
      prefix: keyspace_name,
      consistency: Consistency.device_info(:write)
    ]

    _ = Repo.delete_all(query, opts)

    :ok
  end

  # TODO maybe move to AstarteDataAccess
  def retrieve_device_introspection_map!(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from device in RealmsDevice,
        select: device.introspection,
        where: [device_id: ^device_id]

    opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:read)
    ]

    Repo.one(query, opts) || %{}
  end

  def delete_alias_values!(realm_name, device_alias) do
    keyspace_name = Realm.keyspace_name(realm_name)

    query =
      from Name,
        where: [object_name: ^device_alias]

    opts = [
      prefix: keyspace_name,
      consistency: Consistency.device_info(:write)
    ]

    _ = Repo.delete_all(query, opts)

    :ok
  end

  def retrieve_devices_to_delete!(realm_name) do
    keyspace = Realm.keyspace_name(realm_name)

    opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:read)
    ]

    from(DeletionInProgress)
    |> Repo.all(opts)
    |> Enum.filter(&DeletionInProgress.all_ack?/1)
  end

  def retrieve_kv_store_entries!(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from KvStore,
        hints: ["ALLOW FILTERING"],
        select: [:group, :key],
        where: [key: ^device_id]

    opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:read)
    ]

    Repo.all(query, opts)
  end

  def delete_kv_store_entry!(realm_name, group, key) do
    keyspace_name = Realm.keyspace_name(realm_name)

    query =
      from KvStore,
        where: [group: ^group, key: ^key]

    opts = [
      prefix: keyspace_name,
      consistency: Consistency.device_info(:write)
    ]

    _ = Repo.delete_all(query, opts)

    :ok
  end

  def retrieve_groups_keys!(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from GroupedDevice,
        hints: ["ALLOW FILTERING"],
        select: [:group_name, :insertion_uuid, :device_id],
        where: [device_id: ^device_id]

    opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:read)
    ]

    Repo.all(query, opts)
  end

  def retrieve_aliases!(realm_name, device_id) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from Name,
        hints: ["ALLOW FILTERING"],
        select: [:object_name],
        where: [object_uuid: ^device_id]

    opts = [
      prefix: keyspace,
      consistency: Consistency.device_info(:read)
    ]

    Repo.all(query, opts)
  end

  def remove_device_from_deletion_in_progress!(realm_name, device_id) do
    keyspace_name = Realm.keyspace_name(realm_name)

    query =
      from DeletionInProgress,
        where: [device_id: ^device_id]

    opts = [
      prefix: keyspace_name,
      consistency: Consistency.device_info(:write)
    ]

    _ = Repo.delete_all(query, opts)

    :ok
  end

  def delete_group_values!(realm_name, device_id, group_name, insertion_uuid) do
    keyspace_name = Realm.keyspace_name(realm_name)

    query =
      from GroupedDevice,
        where: [group_name: ^group_name, insertion_uuid: ^insertion_uuid, device_id: ^device_id]

    opts = [
      prefix: keyspace_name,
      consistency: Consistency.device_info(:write)
    ]

    _ = Repo.delete_all(query, opts)

    :ok
  end

  def retrieve_realms!() do
    keyspace = Realm.astarte_keyspace_name()

    opts = [
      prefix: keyspace,
      consistency: Consistency.domain_model(:read)
    ]

    Repo.all(Realm, opts)
  end

  def delete_device!(realm_name, device_id) do
    keyspace_name = Realm.keyspace_name(realm_name)

    query =
      from RealmsDevice,
        where: [device_id: ^device_id]

    # TODO check
    opts = [
      prefix: keyspace_name,
      consistency: Consistency.device_info(:write)
    ]

    _ = Repo.delete_all(query, opts)

    :ok
  end

  def delete_interface(realm_name, interface_name, interface_major_version) do
    _ =
      Logger.info("Delete interface.",
        interface: interface_name,
        interface_major: interface_major_version,
        tag: "db_delete_interface"
      )

    keyspace = Realm.keyspace_name(realm_name)

    interface_id = CQLUtils.interface_id(interface_name, interface_major_version)

    endpoint_query =
      from Endpoint,
        prefix: ^keyspace,
        where: [interface_id: ^interface_id]

    interface_query =
      from Interface,
        prefix: ^keyspace,
        where: [name: ^interface_name, major_version: ^interface_major_version]

    queries = [
      Repo.to_sql(:delete_all, endpoint_query),
      Repo.to_sql(:delete_all, interface_query)
    ]

    consistency = Consistency.domain_model(:write)

    Exandra.execute_batch(
      Repo,
      %Exandra.Batch{
        queries: queries
      },
      consistency: consistency
    )
  end
end
