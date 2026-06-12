#
# This file is part of Astarte.
#
# Copyright 2026 SECO Mind Srl
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

defmodule Astarte.DataAccess.Adapters.InterfaceTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  import Astarte.Core.CQLUtils, only: [interface_name_to_table_name: 2]
  import Astarte.Core.Generators.Interface

  import Astarte.DataAccess.Adapters.Interface

  alias Ecto.Changeset

  alias Astarte.Core.Interface, as: InterfaceCore

  alias Astarte.DataAccess.Realms.Endpoint
  alias Astarte.DataAccess.Realms.Interface

  defp normalize_empty(map, key) do
    case Map.fetch(map, key) do
      {:ok, value} -> value
      :error -> nil
    end
  end

  @moduletag :data_access
  @moduletag :interface
  describe "from core interface to data access changesets" do
    property "ensure all changesets are valid" do
      check all interface <- interface() do
        %{interface: interface, endpoints: endpoints} = from_core_interface_to_change(interface)

        assert %Changeset{valid?: true} = Interface.changeset(%Interface{}, interface)

        for endpoint <- endpoints do
          assert %Changeset{valid?: true} = Endpoint.changeset(%Endpoint{}, endpoint)
        end
      end
    end

    property "ensure all changesets have source fields data" do
      check all %InterfaceCore{} = interface_core <- interface() do
        %{interface: interface, endpoints: endpoints} =
          from_core_interface_to_change(interface_core)

        assert interface_core.interface_id == interface.interface_id
        assert interface_core.name == interface.name
        assert interface_core.major_version == interface.major_version
        assert interface_core.minor_version == interface.minor_version
        assert interface_core.aggregation == interface.aggregation
        assert interface_core.ownership == interface.ownership
        assert interface_core.type == interface.type
        assert interface_core |> Interface.storage() == interface.storage
        assert interface_core |> Interface.storage_type() == interface.storage_type
        assert interface_core.doc == normalize_empty(interface, :doc)
        assert interface_core.description == normalize_empty(interface, :description)

        mappings_endpoints =
          Enum.zip(
            Enum.sort_by(interface_core.mappings, & &1.endpoint_id),
            Enum.sort_by(endpoints, fn endpoint -> endpoint.endpoint_id end)
          )

        for {mapping_core, endpoint} <- mappings_endpoints do
          assert interface_core.interface_id == endpoint.interface_id
          assert mapping_core.endpoint == endpoint.endpoint
          assert mapping_core.value_type == endpoint.value_type
          assert mapping_core.reliability == endpoint.reliability
          assert mapping_core.retention == endpoint.retention
          assert mapping_core.expiry == endpoint.expiry
          assert mapping_core.database_retention_policy == endpoint.database_retention_policy

          assert mapping_core.database_retention_ttl ==
                   normalize_empty(endpoint, :database_retention_ttl)

          assert mapping_core.allow_unset == endpoint.allow_unset
          assert mapping_core.explicit_timestamp == endpoint.explicit_timestamp
          assert mapping_core.endpoint_id == endpoint.endpoint_id
          assert mapping_core.doc == normalize_empty(endpoint, :doc)
          assert mapping_core.description == normalize_empty(endpoint, :description)
        end
      end
    end

    @tag :issue
    property "interface_name_to_table_name works fine" do
      check all interface_core <- interface() do
        %{
          interface: %{name: name, major_version: major_version}
        } =
          from_core_interface_to_change(interface_core)

        assert is_binary(interface_name_to_table_name(name, major_version))
      end
    end
  end
end
