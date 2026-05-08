defmodule Astarte.Core.InterfaceDescriptorTest do
  use ExUnit.Case

  alias Astarte.Core.CQLUtils
  alias Astarte.Core.Interface.Aggregation
  alias Astarte.Core.Interface.Ownership
  alias Astarte.Core.Interface.Type
  alias Astarte.Core.InterfaceDescriptor
  alias Astarte.Core.StorageType

  @interface_fixture_name "com.ispirata.Hemera.Test"
  @interface_fixture_maj 1
  @interface_fixture_min 2
  @interface_fixture_type :properties
  @interface_fixture_type_as_int Type.to_int(@interface_fixture_type)
  @interface_fixture_ownership :server
  @interface_fixture_ownership_as_int Ownership.to_int(@interface_fixture_ownership)
  @interface_fixture_aggregation :individual
  @interface_fixture_aggregation_as_int Aggregation.to_int(@interface_fixture_aggregation)
  @interface_fixture_storage "storage"
  @interface_fixture_storage_type :multi_interface_individual_properties_dbtable
  @interface_fixture_storage_type_as_int StorageType.to_int(@interface_fixture_storage_type)

  @interface_descriptor_fixture %InterfaceDescriptor{
    name: @interface_fixture_name,
    major_version: @interface_fixture_maj,
    minor_version: @interface_fixture_min,
    type: @interface_fixture_type,
    ownership: @interface_fixture_ownership,
    aggregation: @interface_fixture_aggregation,
    storage: @interface_fixture_storage,
    storage_type: @interface_fixture_storage_type,
    automaton: {%{}, %{}},
    interface_id: CQLUtils.interface_id(@interface_fixture_name, @interface_fixture_maj)
  }

  test "keyword list result deserialization" do
    descriptor_as_keyword_list = [
      name: @interface_fixture_name,
      major_version: @interface_fixture_maj,
      minor_version: @interface_fixture_min,
      type: @interface_fixture_type_as_int,
      ownership: @interface_fixture_ownership_as_int,
      aggregation: @interface_fixture_aggregation_as_int,
      storage: @interface_fixture_storage,
      storage_type: @interface_fixture_storage_type_as_int,
      automaton_transitions: :erlang.term_to_binary(%{}),
      automaton_accepting_states: :erlang.term_to_binary(%{}),
      interface_id: CQLUtils.interface_id(@interface_fixture_name, @interface_fixture_maj)
    ]

    assert InterfaceDescriptor.from_db_result!(descriptor_as_keyword_list) ==
             @interface_descriptor_fixture
  end

  test "keyword list deserialization fails if keys are missing" do
    descriptor_as_keyword_list_no_aggr = [
      name: @interface_fixture_name,
      major_version: @interface_fixture_maj,
      minor_version: @interface_fixture_min,
      type: @interface_fixture_type_as_int,
      ownership: @interface_fixture_ownership_as_int
      # Missing aggregation
    ]

    assert_raise ArgumentError, fn ->
      InterfaceDescriptor.from_db_result!(descriptor_as_keyword_list_no_aggr)
    end
  end

  test "map result deserialization" do
    descriptor_as_map = %{
      name: @interface_fixture_name,
      major_version: @interface_fixture_maj,
      minor_version: @interface_fixture_min,
      type: @interface_fixture_type_as_int,
      ownership: @interface_fixture_ownership_as_int,
      aggregation: @interface_fixture_aggregation_as_int,
      storage: @interface_fixture_storage,
      storage_type: @interface_fixture_storage_type_as_int,
      automaton_transitions: :erlang.term_to_binary(%{}),
      automaton_accepting_states: :erlang.term_to_binary(%{}),
      interface_id: CQLUtils.interface_id(@interface_fixture_name, @interface_fixture_maj)
    }

    assert InterfaceDescriptor.from_db_result!(descriptor_as_map) == @interface_descriptor_fixture
  end

  test "map deserialization fails if keys are missing" do
    descriptor_as_map_no_name = %{
      # Missing name
      major_version: @interface_fixture_maj,
      minor_version: @interface_fixture_min,
      type: @interface_fixture_type_as_int,
      ownership: @interface_fixture_ownership_as_int,
      aggregation: @interface_fixture_aggregation_as_int
    }

    assert_raise ArgumentError, fn ->
      InterfaceDescriptor.from_db_result!(descriptor_as_map_no_name)
    end
  end
end
