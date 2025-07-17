defmodule Astarte.DataUpdaterPlant.RPC.Queries do
  import Ecto.Query
  alias Astarte.DataAccess.Consistency
  alias Astarte.DataAccess.Realms.Realm
  alias Astarte.DataAccess.Repo
  alias Astarte.DataAccess.Groups.GroupedDevice
  require Logger

  def fetch_grouped_devices(realm_name, group) do
    keyspace = Realm.keyspace_name(realm_name)

    query =
      from(GroupedDevice,
        hints: ["ALLOW FILTERING"],
        where: [group_name: ^group],
        select: [:device_id]
      )

    consistency = Consistency.domain_model(:read)

    case Repo.fetch_all(query, prefix: keyspace, consistency: consistency) do
      {:ok, result} ->
        device_ids = Enum.map(result, & &1.device_id)

        Logger.info(
          "Fetched device IDs for group #{inspect(group)} in realm #{inspect(realm_name)}: #{inspect(device_ids)}"
        )

        device_ids

      {:error, reason} ->
        Logger.error(
          "Failed to fetch devices for group #{inspect(group)} in realm #{inspect(realm_name)}: #{inspect(reason)}"
        )

        []
    end
  end
end
