defmodule Astarte.Core.StorageTypeTest do
  use ExUnit.Case

  alias Astarte.Core.StorageType

  @valid_atoms [
    :multi_interface_individual_properties_dbtable,
    :multi_interface_individual_datastream_dbtable,
    :one_individual_properties_dbtable,
    :one_individual_datastream_dbtable,
    :one_object_datastream_dbtable
  ]
  @valid_ints [1, 2, 3, 4, 5]

  test "cast/1 with nil returns ok nil" do
    assert {:ok, nil} = StorageType.cast(nil)
  end

  test "cast/1 with valid atoms returns ok" do
    for atom <- @valid_atoms do
      assert {:ok, ^atom} = StorageType.cast(atom)
    end
  end

  test "cast/1 with invalid atom returns error" do
    assert :error = StorageType.cast(:nonexistent_type)
  end

  test "cast/1 with valid integers returns ok" do
    for {atom, int} <- Enum.zip(@valid_atoms, @valid_ints) do
      assert {:ok, ^atom} = StorageType.cast(int)
    end
  end

  test "cast/1 with invalid integer returns error" do
    assert :error = StorageType.cast(999)
  end

  test "cast/1 with other types returns error" do
    assert :error = StorageType.cast("not_an_atom")
    assert :error = StorageType.cast([])
  end

  test "cast!/1 with valid atom returns atom" do
    assert StorageType.cast!(:one_object_datastream_dbtable) == :one_object_datastream_dbtable
  end

  test "cast!/1 with invalid value raises ArgumentError" do
    assert_raise ArgumentError, fn -> StorageType.cast!(:invalid) end
  end

  test "dump/1 with valid atoms returns ok int" do
    assert {:ok, 1} = StorageType.dump(:multi_interface_individual_properties_dbtable)
    assert {:ok, 2} = StorageType.dump(:multi_interface_individual_datastream_dbtable)
    assert {:ok, 3} = StorageType.dump(:one_individual_properties_dbtable)
    assert {:ok, 4} = StorageType.dump(:one_individual_datastream_dbtable)
    assert {:ok, 5} = StorageType.dump(:one_object_datastream_dbtable)
  end

  test "dump/1 with invalid atom returns error" do
    assert :error = StorageType.dump(:invalid_atom)
  end

  test "dump!/1 with invalid atom raises ArgumentError" do
    assert_raise ArgumentError, fn -> StorageType.dump!(:invalid_atom) end
  end

  test "load/1 with valid integers returns ok atom" do
    for {atom, int} <- Enum.zip(@valid_atoms, @valid_ints) do
      assert {:ok, ^atom} = StorageType.load(int)
    end
  end

  test "load/1 with invalid integer returns error" do
    assert :error = StorageType.load(0)
    assert :error = StorageType.load(6)
    assert :error = StorageType.load(999)
  end
end
