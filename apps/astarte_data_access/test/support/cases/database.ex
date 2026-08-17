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

defmodule Astarte.DataAccess.Cases.Database do
  @moduledoc false

  use ExUnit.CaseTemplate

  import Astarte.DataAccess.Helpers.Database

  using opts do
    astarte_instance_id = Keyword.get_lazy(opts, :astarte_instance_id, &astarte_instance_id/0)
    realm_name = Keyword.get_lazy(opts, :realm_name, &realm_name/0)

    quote do
      import Astarte.DataAccess.Cases.Database
      import Astarte.DataAccess.Helpers.Database

      @moduletag astarte_instance_id: unquote(astarte_instance_id)
      @moduletag realm_name: unquote(realm_name)
    end
  end

  setup_all %{realm_name: realm, astarte_instance_id: astarte_instance_id} do
    setup_instance(astarte_instance_id, [realm])
    %{realm: realm, astarte_instance_id: astarte_instance_id}
  end

  setup %{astarte_instance_id: astarte_instance_id} do
    setup_database_access(astarte_instance_id)

    :ok
  end

  def setup_instance(astarte_instance_id \\ nil, realm_names \\ nil) do
    astarte_instance_id = astarte_instance_id || astarte_instance_id()
    realm_names = realm_names || [realm_name()]

    setup_database_access(astarte_instance_id)
    setup_astarte_keyspace()

    for realm_name <- realm_names do
      setup_realm(realm_name)
    end

    on_exit(fn ->
      setup_database_access(astarte_instance_id)
      teardown_astarte_keyspace()

      for realm_name <- realm_names do
        teardown_realm_keyspace(realm_name)
      end
    end)

    %{astarte_instance_id: astarte_instance_id, realm_names: realm_names}
  end

  def seed_data(%{realm_name: realm_name}) do
    seed_database(realm_name)
    :ok
  end

  defp astarte_instance_id, do: "test#{System.unique_integer([:positive])}"
  defp realm_name, do: "realm#{System.unique_integer([:positive])}"
end
