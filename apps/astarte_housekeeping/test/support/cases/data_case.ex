#
# This file is part of Astarte.
#
# Copyright 2017 - 2025 SECO Mind Srl
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

defmodule Astarte.Housekeeping.DataCase do
  use ExUnit.CaseTemplate
  alias Astarte.Housekeeping.Helpers.Database

  setup_all do
    astarte_instance_id = "astarte#{System.unique_integer([:positive])}"
    realm_name = "realm#{System.unique_integer([:positive])}"
    Database.setup_database_access(astarte_instance_id)
    Database.setup(realm_name)

    on_exit(fn ->
      Database.setup_database_access(astarte_instance_id)
      Database.teardown(realm_name)
    end)

    %{astarte_instance_id: astarte_instance_id, realm_name: realm_name}
  end

  setup context do
    %{astarte_instance_id: astarte_instance_id} = context
    Database.setup_database_access(astarte_instance_id)

    :ok
  end
end
