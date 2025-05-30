#
# This file is part of Astarte.
#
# Copyright 2025 SECO Mind Srl
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

defmodule Astarte.DataUpdaterPlant.DataUpdater.QueriesTest do
  use Astarte.Cases.Data, async: true
  use Astarte.Cases.Device
  use ExUnitProperties
  alias Astarte.Core.Generators.Realm, as: RealmGenerator
  alias Astarte.DataUpdaterPlant.DataUpdater.Queries

  describe "retrieve_realms!/0" do
    setup do
      astarte_instance_id = "custom#{System.unique_integer([:positive])}"

      realm_names =
        list_of(RealmGenerator.realm_name(), min_length: 5)
        |> resize(5)
        |> Enum.at(0)
        |> Enum.sort()
        |> Enum.dedup()

      setup_instance(astarte_instance_id, realm_names)

      %{astarte_instance_id: astarte_instance_id, realm_names: realm_names}
    end

    test "returns the list of realms", %{realm_names: expected_realms} do
      realms = Queries.retrieve_realms!() |> Enum.map(& &1["realm_name"]) |> Enum.sort()
      assert realms == expected_realms
    end
  end
end
