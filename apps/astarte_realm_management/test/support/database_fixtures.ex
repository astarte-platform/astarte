#
# This file is part of Astarte.
#
# Copyright 2023 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

defmodule Astarte.RealmManagement.DatabaseFixtures do
  alias Astarte.Core.Device
  alias Astarte.Core.CQLUtils

  def datastream_values do
    [
      realm_name: "realm#{System.unique_integer([:positive])}",
      device_id: Device.random_device_id(),
      interface_name: "com.datastream.Interface#{System.unique_integer([:positive])}",
      interface_major: System.unique_integer([:positive]),
      endpoint: "/%{sensorId}/value",
      path: "/the_#{System.unique_integer([:positive])}_th/value",
      value_timestamp: DateTime.utc_now(),
      reception_timestamp: DateTime.utc_now(),
      reception_timestamp_submillis: System.unique_integer([:positive]),
      value: System.unique_integer([:positive])
    ]
  end

  def properties_values do
    [
      realm_name: "realm#{System.unique_integer([:positive])}",
      device_id: Device.random_device_id(),
      interface_name: "com.properties.Interface#{System.unique_integer([:positive])}",
      interface_major: System.unique_integer([:positive]),
      endpoint: "/%{sensorId}/value",
      path: "/the_#{System.unique_integer([:positive])}_th/value",
      reception_timestamp: DateTime.utc_now(),
      reception_timestamp_submillis: System.unique_integer([:positive]),
      value: System.unique_integer([:positive])
    ]
  end

  def introspection_values do
    [
      realm_name: "realm#{System.unique_integer([:positive])}",
      device_id: Device.random_device_id(),
      interface_name: "com.Interface#{System.unique_integer([:positive])}",
      interface_major: System.unique_integer([:positive])
    ]
  end

  def alias_values do
    [
      realm_name: "realm#{System.unique_integer([:positive])}",
      device_alias: "alias_n_#{System.unique_integer([:positive])}",
      device_id: Device.random_device_id()
    ]
  end

  def group_values do
    [
      realm_name: "realm#{System.unique_integer([:positive])}",
      device_id: Device.random_device_id(),
      group_name: "group_n_#{System.unique_integer([:positive])}",
      insertion_uuid: time_uuid()
    ]
  end

  def kv_store_values do
    [
      realm_name: "realm#{System.unique_integer([:positive])}",
      group: "group_n_#{System.unique_integer([:positive])}",
      key: "key_n_#{System.unique_integer([:positive])}",
      value: "bigintAsBlob(#{System.unique_integer([:positive])})"
    ]
  end

  def devices_values do
    [
      realm_name: "realm#{System.unique_integer([:positive])}",
      device_id: Device.random_device_id()
    ]
  end

  def interfaces_object_values do
    interface_name = "com.object.datastream.Interface#{System.unique_integer([:positive])}"
    interface_major = System.unique_integer([:positive])

    [
      realm_name: "realm#{System.unique_integer([:positive])}",
      interface_name: interface_name,
      interface_major: interface_major,
      interface_minor: System.unique_integer([:positive]),
      # Object aggregated interfaces have always storage type 5 (:one_object_datastream_dbtable)
      storage_type: 5,
      storage: CQLUtils.interface_name_to_table_name(interface_name, interface_major),
      type: Enum.random([1, 2]),
      ownership: Enum.random([1, 2]),
      # Object aggregated interfaces have always aggregation type 2 (:object)
      aggregation: 2,
      automaton_transitions: :erlang.term_to_binary(<<>>),
      automaton_accepting_states: :erlang.term_to_binary(<<>>),
      description: "",
      doc: ""
    ]
  end

  def compute_interface_fixtures(opts, fixtures) do
    fixtures = Keyword.merge(fixtures, opts)
    interface_id = CQLUtils.interface_id(fixtures[:interface_name], fixtures[:interface_major])

    endpoint_id =
      CQLUtils.endpoint_id(
        fixtures[:interface_name],
        fixtures[:interface_major],
        fixtures[:endpoint]
      )

    # Xandra accepts only maps, not keyword lists
    Enum.into(fixtures, %{
      interface_id: interface_id,
      endpoint_id: endpoint_id
    })
  end

  def compute_alias_fixtures(opts, fixtures) do
    fixtures = Keyword.merge(fixtures, opts)

    # Xandra accepts only maps, not keyword lists
    %{
      realm_name: fixtures[:realm_name],
      object_name: fixtures[:device_alias],
      object_uuid: fixtures[:device_id]
    }
  end

  def compute_interfaces_object_fixtures(opts, fixtures) do
    fixtures = Keyword.merge(fixtures, opts)
    interface_id = CQLUtils.interface_id(fixtures[:interface_name], fixtures[:interface_major])

    # Xandra accepts only maps, not keyword lists
    %{
      realm_name: fixtures[:realm_name],
      name: fixtures[:interface_name],
      major_version: fixtures[:interface_major],
      minor_version: fixtures[:interface_minor],
      interface_id: interface_id,
      storage_type: fixtures[:storage_type],
      storage: fixtures[:storage],
      type: fixtures[:type],
      ownership: fixtures[:ownership],
      aggregation: fixtures[:aggregation],
      automaton_transitions: fixtures[:automaton_transitions],
      automaton_accepting_states: fixtures[:automaton_accepting_states],
      description: fixtures[:description],
      doc: fixtures[:doc]
    }
  end

  def compute_introspection_fixtures(opts, fixtures) do
    fixtures = Keyword.merge(fixtures, opts)

    # Xandra accepts only maps, not keyword lists
    %{
      realm_name: fixtures[:realm_name],
      device_id: fixtures[:device_id],
      introspection: %{fixtures[:interface_name] => fixtures[:interface_major]}
    }
  end

  def compute_generic_fixtures(opts, fixtures) do
    # Xandra accepts only maps, not keyword lists
    Keyword.merge(fixtures, opts) |> Enum.into(%{})
  end

  def realm_values do
    [
      realm_name: "realm#{System.unique_integer([:positive])}",
      device_registration_limit: System.unique_integer([:positive])
    ]
  end

  defp time_uuid do
    {time_uuid, _state} = :uuid.get_v1(:uuid.new(self()))
    time_uuid
  end
end
