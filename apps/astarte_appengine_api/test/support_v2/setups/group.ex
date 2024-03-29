defmodule Astarte.Test.Setups.Group do
  use ExUnit.Case, async: false
  alias Astarte.Test.Helpers.Database, as: DatabaseHelper
  alias Astarte.Test.Generators.Group, as: GroupGenerator

  def init(%{group_count: group_count, devices: devices}) do
    {:ok, groups: GroupGenerator.group(devices: devices) |> Enum.take(group_count)}
  end

  def setup(%{cluster: cluster, keyspace: keyspace, groups: groups}) do
    on_exit(fn ->
      DatabaseHelper.delete!(:group, cluster, keyspace, groups)
    end)

    DatabaseHelper.insert!(:group, cluster, keyspace, groups)
    :ok
  end
end
