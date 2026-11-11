defmodule Astarte.DataUpdaterPlant.DeletionSchedulerTest do
  use Astarte.Cases.Data, async: true
  use Mimic

  alias Astarte.Core.Device
  alias Astarte.DataAccess.Config
  alias Astarte.DataAccess.Device.DeletionInProgress
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.DataUpdater.DeletionScheduler
  alias Astarte.DataUpdaterPlant.DataUpdater

  setup_all context do
    %{realm_name: realm_name} = context

    device_id = Device.random_device_id()
    encoded_device_id = Device.encode_device_id(device_id)

    entry = %DeletionInProgress{
      device_id: device_id,
      vmq_ack: false,
      dup_start_ack: false,
      dup_end_ack: false
    }

    Repo.insert(entry, prefix: Realm.keyspace_name(realm_name))

    scheduler = start_supervised!(DeletionScheduler, [])

    %{scheduler: scheduler, device_id: device_id, encoded_device_id: encoded_device_id}
  end

  setup context do
    %{scheduler: scheduler} = context
    Mimic.allow(DataUpdater, self(), scheduler)
    Mimic.allow(Config, self(), scheduler)

    :ok
  end

  test "re-triggers device deletion for existing entries", context do
    %{encoded_device_id: encoded_device_id, scheduler: scheduler, realm_name: realm_name} =
      context

    test_process = self()

    DataUpdater
    |> expect(:start_device_deletion, fn ^realm_name, ^encoded_device_id, _timestamp ->
      send(test_process, :started_device_deletion)
      :ok
    end)

    send(scheduler, :delete_devices)

    assert_receive :started_device_deletion
  end
end
