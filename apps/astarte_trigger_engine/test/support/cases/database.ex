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

defmodule Astarte.Cases.Database do
  use ExUnit.CaseTemplate
  use Mimic

  using opts do
    astarte_instance_id =
      Keyword.get_lazy(opts, :astarte_instance_id, fn ->
        "test#{System.unique_integer([:positive])}"
      end)

    realm_name =
      Keyword.get_lazy(opts, :realm_name, fn ->
        "realm#{System.unique_integer([:positive])}"
      end)

    quote do
      @moduletag astarte_instance_id: unquote(astarte_instance_id)
      @moduletag realm_name: unquote(realm_name)
    end
  end

  alias Astarte.Helpers.Database

  setup_all %{realm_name: realm_name, astarte_instance_id: astarte_instance_id} do
    on_exit(fn ->
      Database.setup_database_access(astarte_instance_id)
      Database.teardown!(realm_name)
    end)

    Database.setup_database_access(astarte_instance_id)
    Database.setup!(realm_name)

    :ok
  end

  setup %{astarte_instance_id: astarte_instance_id} do
    Database.setup_database_access(astarte_instance_id)

    :ok
  end
end
