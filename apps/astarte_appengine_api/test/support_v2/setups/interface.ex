defmodule Astarte.Test.Setups.Interface do
  use ExUnit.Case, async: false
  alias Astarte.Test.Helpers.Database, as: DatabaseHelper
  alias Astarte.Test.Generators.Interface, as: InterfaceGenerator

  def init(%{interface_count: interface_count}) do
    {:ok, interfaces: InterfaceGenerator.interface() |> Enum.take(interface_count)}
  end

  def setup(%{cluster: cluster, keyspace: keyspace, interfaces: interfaces}) do
    on_exit(fn ->
      DatabaseHelper.delete!(:interface, cluster, keyspace, interfaces)
    end)

    DatabaseHelper.insert!(:interface, cluster, keyspace, interfaces)
    :ok
  end
end
