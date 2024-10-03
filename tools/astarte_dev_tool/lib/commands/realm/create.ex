#
# This file is part of Astarte.
#
# Copyright 2024 SECO Mind Srl
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

defmodule AstarteDevTool.Commands.Realm.Create do
  @moduledoc false
  alias Astarte.DataAccess.Database
  alias Astarte.DataAccess.Realm, as: RealmDataAccess

  @start_apps [
    :logger,
    :crypto,
    :ssl,
    :xandra,
    :astarte_data_access
  ]
  def exec(
        [{_, _} | _] = nodes,
        realm_name,
        replication \\ 1,
        max_retention \\ 1,
        public_key_pem \\ "@@@@",
        device_registration_limit \\ nil,
        realm_schema_version \\ 10
      ) do
    with :ok <- Enum.each(@start_apps, &Application.ensure_all_started/1),
         {:ok, _client} <- Database.connect(cassandra_nodes: nodes),
         :ok <-
           RealmDataAccess.create_realm(
             realm_name,
             replication,
             max_retention,
             public_key_pem,
             device_registration_limit,
             realm_schema_version
           ) do
      :ok
    end
  end
end
