defmodule Astarte.Test.Setups.Database do
  use ExUnit.Case, async: false
  alias Astarte.Test.Generators.Common, as: CommonGenerator
  alias Astarte.Test.Helpers.Database, as: DatabaseHelper
  alias Astarte.Test.Helpers.JWT, as: JWTHelper

  # TODO
  # doctest Astarte.Test.Fixture.Database

  def connect(_context) do
    {:ok, cluster: :xandra}
  end

  def keyspace(_context) do
    {:ok, keyspace: CommonGenerator.keyspace_name() |> Enum.at(0)}
  end

  def setup(%{cluster: cluster, keyspace: keyspace}) do
    on_exit(fn ->
      DatabaseHelper.destroy_test_keyspace!(cluster, keyspace)
    end)

    DatabaseHelper.create_test_keyspace!(cluster, keyspace)
    {:ok, keyspace: keyspace}
  end

  def setup_auth(%{cluster: cluster, keyspace: keyspace}) do
    on_exit(fn ->
      DatabaseHelper.delete!(:pubkeypem, cluster, keyspace)
    end)

    DatabaseHelper.insert!(:pubkeypem, cluster, keyspace, JWTHelper.public_key_pem())
    {:ok, keyspace: keyspace}
  end
end
