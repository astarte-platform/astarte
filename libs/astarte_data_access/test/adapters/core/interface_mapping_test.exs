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

defmodule Astarte.DataAccess.Adapters.Core.InterfaceMappingTest do
  use ExUnit.Case
  use ExUnitProperties

  import Astarte.Core.Generators.Interface

  import Astarte.DataAccess.Adapters.Core.InterfaceMapping

  alias Ecto.Changeset

  alias Astarte.Core.Interface, as: InterfaceCore

  alias Astarte.DataAccess.Realms.Interface

  defp valid_interface?(%{doc: d, description: desc, mappings: m}),
    do: valid_str?(d) and valid_str?(desc) and Enum.all?(m, &valid_mapping?/1)

  defp valid_mapping?(%{doc: d, description: desc}), do: valid_str?(d) and valid_str?(desc)

  defp valid_str?(nil), do: true
  defp valid_str?(str), do: str |> String.trim() |> String.length() > 0

  @moduletag :adapters
  describe "from core interface" do
    property "ensure all changesets are valid" do
      check all interface <- interface() do
        %{interface: interface, endpoints: endpoints} = from_core_interface(interface)

        assert interface.valid?
        assert Enum.all?(endpoints, & &1.valid?)
      end
    end

    property "ensure all changesets have source fields data" do
      check all %InterfaceCore{} = interface_core <- interface() |> filter(&valid_interface?/1) do
        %{interface: interface_changeset, endpoints: endpoint_changesets} =
          from_core_interface(interface_core)

        assert interface_core.interface_id ==
                 Changeset.get_field(interface_changeset, :interface_id)

        assert interface_core.name ==
                 Changeset.get_field(interface_changeset, :name)

        assert interface_core.major_version ==
                 Changeset.get_field(interface_changeset, :major_version)

        assert interface_core.minor_version ==
                 Changeset.get_field(interface_changeset, :minor_version)

        assert interface_core.aggregation ==
                 Changeset.get_field(interface_changeset, :aggregation)

        assert interface_core.ownership ==
                 Changeset.get_field(interface_changeset, :ownership)

        assert interface_core.type ==
                 Changeset.get_field(interface_changeset, :type)

        assert interface_core |> Interface.storage() ==
                 Changeset.get_field(interface_changeset, :storage)

        assert interface_core |> Interface.storage_type() ==
                 Changeset.get_field(interface_changeset, :storage_type)

        assert interface_core.doc ==
                 Changeset.get_field(interface_changeset, :doc)

        assert interface_core.description ==
                 Changeset.get_field(interface_changeset, :description)

        mappings_endpoints =
          Enum.zip(
            Enum.sort_by(interface_core.mappings, & &1.endpoint_id),
            Enum.sort_by(endpoint_changesets, &Ecto.Changeset.get_field(&1, :endpoint_id))
          )

        for {mapping_core, endpoint_changeset} <- mappings_endpoints do
          assert interface_core.interface_id ==
                   Changeset.get_field(endpoint_changeset, :interface_id)

          assert mapping_core.endpoint ==
                   Changeset.get_field(endpoint_changeset, :endpoint)

          assert mapping_core.value_type ==
                   Changeset.get_field(endpoint_changeset, :value_type)

          assert mapping_core.reliability ==
                   Changeset.get_field(endpoint_changeset, :reliability)

          assert mapping_core.retention ==
                   Changeset.get_field(endpoint_changeset, :retention)

          assert mapping_core.expiry ==
                   Changeset.get_field(endpoint_changeset, :expiry)

          assert mapping_core.database_retention_policy ==
                   Changeset.get_field(endpoint_changeset, :database_retention_policy)

          assert mapping_core.database_retention_ttl ==
                   Changeset.get_field(endpoint_changeset, :database_retention_ttl)

          assert mapping_core.allow_unset ==
                   Changeset.get_field(endpoint_changeset, :allow_unset)

          assert mapping_core.explicit_timestamp ==
                   Changeset.get_field(endpoint_changeset, :explicit_timestamp)

          assert mapping_core.endpoint_id ==
                   Changeset.get_field(endpoint_changeset, :endpoint_id)

          assert mapping_core.doc ==
                   Changeset.get_field(endpoint_changeset, :doc)

          assert mapping_core.description ==
                   Changeset.get_field(endpoint_changeset, :description)
        end
      end
    end
  end
end
